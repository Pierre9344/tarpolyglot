# Step workers. These are called (as tarpolyglot::run_py_step / run_jl_step) from the command of the target built by the tar_target_*() constructors, so they must be exported. Users normally do not call them directly.

#' Execute a Python step (worker behind tar_target_py)
#'
#' Runs, inside a fresh R environment, an optional R pre-script, a Python script (via \pkg{reticulate}), and an optional R post-script, then returns either a converted R object or a character vector of files. This is the function the target built by [tar_target_py()] calls; it is exported so that call resolves at pipeline run time but this function is not destined to be called directly by the package users.
#'
#' @inheritParams tarpolyglot-shared-params
#' @param script Path to the Python script to run (required).
#' @param pre_script Optional path to an R script run before the Python script. It is evaluated in the step environment, which already holds the named `inputs`. To hand objects to Python, assign a named list `to_py` in this script; each element is pushed as a top-level variable in the Python `__main__` module.
#' @param post_script Optional path to an R script run after the Python script. It is evaluated in the same environment, which now also holds `py` (the reticulate `__main__` module proxy) and `py_get(name)`. In `output = "object"` mode the value of its last expression becomes the target value; in `output = "file"` mode it must return a character vector of file paths.
#' @param inputs Named list of upstream target values, bound by name into the step environment. Supplied automatically by the constructor.
#' @param python_version Optional Python version to select (e.g. `"3.12"` or `">=3.11"`), used only when no environment and no explicit `python` path are given. reticulate fetches/selects it (via its uv-backed ephemeral environment) with [reticulate::py_require()]. Default `NULL` uses the computer/global default Python. Use this when you only care about the interpreter *version* and are happy for reticulate to build a *throwaway* environment; for a *pinned, reproducible* environment use `env` / `env_manager` (or `python`) instead.
#' @param env,env_manager,python Python environment selection: the reproducible alternatives to `python_version`. Use `env` + `env_manager` to point at an existing environment built by a known tool, or `python` for one explicit interpreter path. `env_manager` is one of `"system"`, `"virtualenv"`, `"venv"`, `"conda"`, `"uv"`, `"poetry"`; `env` is the corresponding virtualenv/conda name or path (or poetry project directory); `python` is an explicit interpreter path. Precedence: `python` > environment (`env`/`env_manager`) > `python_version` > default. (`"virtualenv"`, `"venv"` and `"uv"` all point at a standard virtualenv, including one created by `renv::use_python()`, and behave identically.) For `"virtualenv"`/`"venv"`/`"uv"`/`"poetry"`, an `env` that is an already-existing directory (relative to the working directory, or absolute) is resolved to an absolute path before use, so a relative venv path (e.g. `".venv"`, created with `uv venv .venv`) works as expected; otherwise `reticulate::use_virtualenv()` would misread a separator-less relative path as the *name* of an environment under its own virtualenv root instead of a path on disk. A bare name that does not correspond to an existing directory is passed through unchanged, so a genuine named environment (one already registered under that root) still resolves. When `python` or an environment is given, the selection also takes priority over an ambient `RETICULATE_PYTHON` environment variable (e.g. one set by the RStudio project Python config and inherited by `crew` workers), which reticulate would otherwise let silently override the request.
#'
#' @return The converted R object (object mode) or a character vector of normalised file paths (file mode).
#' @seealso [run_jl_step()], [tar_target_py()]
#' @export
#' @examples
#' \dontrun{
#' # Normally invoked by tar_target_py(); shown here as a direct call.
#' # scripts/sum.py assigns `result`; pre.R builds `to_py <- list(x = x)`.
#' run_py_step(
#'   script = "scripts/sum.py",
#'   pre_script = "scripts/pre.R",
#'   inputs = list(x = c(1, 2, 3)),
#'   retrieve = "result"
#' )
#' }
run_py_step <- function(script,
                        pre_script = NULL,
                        post_script = NULL,
                        inputs = list(),
                        output = "object",
                        retrieve = NULL,
                        files = NULL,
                        python_version = NULL,
                        env = NULL,
                        env_manager = "system",
                        python = NULL) {
  output <- .tp_match_output(output)
  .tp_assert_script(script, "script", must_exist = TRUE)

  e <- new.env(parent = globalenv())
  for (nm in names(inputs)) assign(nm, inputs[[nm]], envir = e)

  # 1. Configure the interpreter before any Python call.
  .tp_resolve_python(python_version = python_version, env = env,
    env_manager = env_manager, python = python)

  # 2. Pre-R script + push `to_py` into the Python __main__ module.
  if (!is.null(pre_script)) {
    .tp_assert_script(pre_script, "pre_script", must_exist = TRUE)
    .tp_eval_script(pre_script, e)
    if (exists("to_py", envir = e, inherits = FALSE)) {
      to_py <- get("to_py", envir = e)
      main <- reticulate::import_main(convert = TRUE)
      for (nm in names(to_py)) main[[nm]] <- to_py[[nm]]
    }
  }

  # 3. Run the Python script (in __main__): a file on disk, or inline source.
  if (inherits(script, "tp_source")) {
    reticulate::py_run_string(script$code)
  } else {
    reticulate::py_run_file(script)
  }

  # 4. Retrieve output.
  py <- reticulate::import_main(convert = TRUE)
  assign("py", py, envir = e)
  assign("py_get", function(name) reticulate::py_to_r(py[[name]]), envir = e)

  if (identical(output, "file")) {
    paths <- if (!is.null(post_script)) {
      .tp_assert_script(post_script, "post_script", must_exist = TRUE)
      .tp_eval_script(post_script, e)
    } else {
      files
    }
    if (is.null(paths)) {
      stop("output = \"file\" needs a `post_script` returning paths, or `files`.",
        call. = FALSE)
    }
    return(normalizePath(as.character(paths), winslash = "/", mustWork = FALSE))
  }

  # object mode
  if (!is.null(post_script)) {
    .tp_assert_script(post_script, "post_script", must_exist = TRUE)
    return(.tp_eval_script(post_script, e))
  }
  if (!is.null(retrieve)) {
    vals <- lapply(retrieve, function(n) reticulate::py_to_r(py[[n]]))
    if (length(retrieve) == 1L) return(vals[[1L]])
    return(stats::setNames(vals, retrieve))
  }
  stop("output = \"object\" needs either a `post_script` or `retrieve`.",
    call. = FALSE)
}

#' Execute a Julia step (worker behind tar_target_jl)
#'
#' Julia counterpart of [run_py_step()]. Runs, inside a fresh R environment, an optional R pre-script, a Python script (via \pkg{JuliaCall}). This is the function the target built by [tar_target_jl()] calls; it is exported so that call resolves at pipeline run time but this function is not destined to be called directly by the package users.
#'
#'
#' @inheritParams tarpolyglot-shared-params
#' @param script Path to the Julia script to run (required).
#' @param pre_script Optional path to an R script run before the Julia script. It is evaluated in the step environment, which already holds the named `inputs`. To hand objects to Julia, assign a named list `to_jl` in this script; each element is `julia_assign()`ed as a variable in Julia's `Main` module.
#' @param post_script Optional path to an R script run after the Julia script. It is evaluated in the same environment, which now also holds `jl_get(name)` and `jl_call(fn, ...)`. In `output = "object"` mode the value of its last expression becomes the target value; in `output = "file"` mode it must return a character vector of file paths.
#' @param inputs Named list of upstream target values, bound by name into the step environment. Supplied automatically by the constructor.
#' @param julia_version Optional Julia version to select (e.g. `"1.11"`), used when `julia_home` is not given. Resolved to a [juliaup](https://github.com/JuliaLang/juliaup)-managed install. Default `NULL` uses the computer/global default Julia.
#' @param julia_home,julia_project,julia_packages Julia environment selection. `julia_home` is the directory containing the julia executable (defaults to `getOption("tarpolyglot.julia_home")`; when unset and no `julia_version`, JuliaCall discovers Julia on `PATH`). `julia_project` is a Julia project environment (folder with `Project.toml` / `Manifest.toml`) to `Pkg.activate()`; when `NULL`, Julia's default global environment (`@v#.#`) is used. `julia_packages` is a character vector of packages to `using` before the script. The requested environment takes priority over an ambient `JULIA_PROJECT` environment variable (e.g. one set by an RStudio project config and inherited by `crew` workers): it is cleared for the duration of the Julia binding, so an explicit `julia_project` (or the global environment you get when none is given) wins over it, rather than `JULIA_PROJECT` silently selecting a different project. (`JULIA_HOME` is not cleared: it is a supported way to point at the default Julia.)
#'
#' @return The converted R object (object mode) or a character vector of normalised file paths (file mode).
#' @seealso [run_py_step()], [tar_target_jl()]
#' @export
#' @examples
#' \dontrun{
#' # Normally invoked by tar_target_jl(); shown here as a direct call.
#' # scripts/sum.jl assigns `result`; pre.R builds `to_jl <- list(x = x)`.
#' run_jl_step(
#'   script = "scripts/sum.jl",
#'   pre_script = "scripts/pre.R",
#'   inputs = list(x = c(1, 2, 3)),
#'   retrieve = "result"
#' )
#' }
run_jl_step <- function(script,
                        pre_script = NULL,
                        post_script = NULL,
                        inputs = list(),
                        output = "object",
                        retrieve = NULL,
                        files = NULL,
                        julia_version = NULL,
                        julia_home = getOption("tarpolyglot.julia_home"),
                        julia_project = NULL,
                        julia_packages = NULL) {
  output <- .tp_match_output(output)
  .tp_assert_script(script, "script", must_exist = TRUE)

  e <- new.env(parent = globalenv())
  for (nm in names(inputs)) assign(nm, inputs[[nm]], envir = e)

  # 1. Configure Julia before any call.
  .tp_resolve_julia(julia_version = julia_version, julia_home = julia_home,
    julia_project = julia_project, julia_packages = julia_packages)

  # 2. Pre-R script + push `to_jl` into Main.
  if (!is.null(pre_script)) {
    .tp_assert_script(pre_script, "pre_script", must_exist = TRUE)
    .tp_eval_script(pre_script, e)
    if (exists("to_jl", envir = e, inherits = FALSE)) {
      to_jl <- get("to_jl", envir = e)
      for (nm in names(to_jl)) JuliaCall::julia_assign(nm, to_jl[[nm]])
    }
  }

  # 3. Run the Julia script (in Main): a file on disk, or inline source. Inline
  # code is written to a temp .jl and `julia_source()`d, exactly like a file, so
  # multi-statement scripts parse correctly (`julia_command()` only accepts a
  # single expression, so it fails on e.g. a function definition plus a call).
  if (inherits(script, "tp_source")) {
    tmp <- tempfile(fileext = ".jl")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(script$code, tmp)
    JuliaCall::julia_source(tmp)
  } else {
    JuliaCall::julia_source(script)
  }

  # 4. Retrieve output.
  assign("jl_get", function(name) JuliaCall::julia_eval(name), envir = e)
  assign("jl_call", JuliaCall::julia_call, envir = e)

  if (identical(output, "file")) {
    paths <- if (!is.null(post_script)) {
      .tp_assert_script(post_script, "post_script", must_exist = TRUE)
      .tp_eval_script(post_script, e)
    } else {
      files
    }
    if (is.null(paths)) {
      stop("output = \"file\" needs a `post_script` returning paths, or `files`.",
        call. = FALSE)
    }
    return(normalizePath(as.character(paths), winslash = "/", mustWork = FALSE))
  }

  if (!is.null(post_script)) {
    .tp_assert_script(post_script, "post_script", must_exist = TRUE)
    return(.tp_eval_script(post_script, e))
  }
  if (!is.null(retrieve)) {
    vals <- lapply(retrieve, function(n) JuliaCall::julia_eval(n))
    if (length(retrieve) == 1L) return(vals[[1L]])
    return(stats::setNames(vals, retrieve))
  }
  stop("output = \"object\" needs either a `post_script` or `retrieve`.",
    call. = FALSE)
}
