# Per-process cache of the currently-bound wrapper closures for each Rcpp
# module name (e.g. "sourceCpp_2"), keyed by the compiled library's content.
# See run_cpp_step_prebuilt() for why this exists and why it is NOT the same
# trick run_rs_step_prebuilt() uses for Rust.
.tp_cpplib_state <- new.env(parent = emptyenv())

# Rcpp/sourceCpp compiles via R's own configured toolchain (R CMD SHLIB), so,
# unlike Rust, there is no separate compiler to locate -- but on Windows R
# still needs Rtools' shell/make/gcc on PATH to run that build from a bare
# process. Mirrors .tp_with_rust_build_env() (see run-step-rs.R) minus the
# Rust-specific bits (no R_HOME forcing, no cargo). Returns a zero-arg
# restore function.
.tp_with_cpp_build_env <- function() {
  old_path <- Sys.getenv("PATH")
  restore <- function() Sys.setenv(PATH = old_path)

  add <- c(R.home("bin"), file.path(R.home("bin"), "x64"))
  if (.Platform$OS.type == "windows") {
    rt <- Sys.getenv("RTOOLS45_HOME", unset = "")
    for (d in c(if (nzchar(rt)) file.path(rt, "usr", "bin"),
                "C:/rtools45/usr/bin", "C:/rtools44/usr/bin")) {
      if (dir.exists(d)) {
        add <- c(add, d)
        break
      }
    }
  }
  add <- add[dir.exists(add)]
  if (length(add)) {
    Sys.setenv(PATH = paste(c(add, old_path), collapse = .Platform$path.sep))
  }
  restore
}

# Shared tail of the C++ workers: with the compiled functions and `inputs`
# already bound in `e`, evaluate the R post-script and produce the target
# value (object mode) or a character vector of normalised file paths (file
# mode). Identical in shape to run-step-rs.R's .tp_rs_finish() (kept as a
# separate copy rather than a cross-file refactor, to avoid touching the
# already-shipped Rust implementation while this is developed in isolation).
.tp_cpp_finish <- function(e, post_script, output, files) {
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

  if (is.null(post_script)) {
    stop("output = \"object\" needs a `post_script` that calls the compiled C++ ",
      "function(s) and returns a value.", call. = FALSE)
  }
  .tp_assert_script(post_script, "post_script", must_exist = TRUE)
  .tp_eval_script(post_script, e)
}

#' Execute a C++ step (worker behind tar_target_cpp)
#'
#' Compiles the `// [[Rcpp::export]]` functions in a C++ script with [Rcpp::sourceCpp()], exposing them as R functions in a fresh environment, then evaluates an R **post-script** in that environment where you call those functions and return the result. Upstream `inputs` are bound in the same environment. This is the function the target built by [tar_target_cpp()] calls; it is exported so the call resolves at run time, but package users should not call it directly.
#'
#' Unlike Python/Julia there is **no pre-script** for C++ and no live interpreter: `sourceCpp()` compiles a shared library and R calls into it with real type conversion (via [Rcpp](https://www.rcpp.org/)). Header-only extension packages such as RcppArmadillo/RcppEigen need no special handling: declare them with a `// [[Rcpp::depends(pkgname)]]` attribute directly in the C++ source, exactly as in any other Rcpp usage, and `sourceCpp()` picks it up. `sourceCpp()` compiles via R's own configured toolchain (`R CMD SHLIB`), so, unlike Rust, there is no separate compiler/ABI to match -- on Windows this function still puts Rtools on `PATH` for the build itself, since a bare or `crew`-worker process may not otherwise have it there.
#'
#' @inheritParams tarpolyglot-shared-params
#' @inheritSection tarpolyglot-shared-params Script arguments
#' @param script Path to the C++ script containing `// [[Rcpp::export]]` functions (required). Accepts a file path or an inline [tar_code()] carrier; see the "Script arguments" section below.
#' @param post_script Path to an R script evaluated after compilation. The compiled C++ functions and the named `inputs` are in scope; its last expression is the target value (object mode), or it returns a character vector of file paths (file mode). Required for object mode. Accepts a file path or an inline [tar_code()] carrier; see the "Script arguments" section below.
#' @param depends Optional character vector of extension packages (e.g. `c("RcppArmadillo", "RcppEigen")`), passed straight through as `// [[Rcpp::depends(...)]]` would be. Usually unnecessary: declaring `// [[Rcpp::depends(pkgname)]]` directly in the C++ source (the normal Rcpp convention) already works, so this argument is only useful if you would rather not repeat that in the source itself.
#' @param name Character string, the step's target name. Supplied automatically by the constructor; used only to name this step's log files when [polyglot_controller()] was given a [tar_polyglot_log()] (`NULL` -- the default -- disables logging for a direct call). Only `Rcpp::Rcout`/`Rcpp::Rcerr` output from the post-script's calls into compiled code is captured; see [tar_polyglot_log()].
#'
#' @return The value of the post-script (object mode) or a character vector of normalised file paths (file mode).
#' @seealso [tar_target_cpp()], [run_py_step()], [run_jl_step()], [run_rs_step()]
#' @export
#' @examples
#' # This worker compiles C++, so it only runs when TARPOLYGLOT_EXAMPLES=true
#' # says a compiler reachable by R is available. tar_dir() runs the code in a
#' # temporary directory.
#' if (identical(Sys.getenv("TARPOLYGLOT_EXAMPLES"), "true")) {
#'   targets::tar_dir({
#'     # Normally invoked by tar_target_cpp(); shown here as a direct call.
#'     writeLines(
#'       c("#include <Rcpp.h>",
#'         "// [[Rcpp::export]]",
#'         "double square(double x) { return x * x; }"),
#'       "square.cpp"
#'     )
#'     writeLines("square(x)", "post.R")
#'     run_cpp_step(
#'       script = "square.cpp",
#'       inputs = list(x = 21),
#'       post_script = "post.R"
#'     )
#'   })
#' }
run_cpp_step <- function(script,
                         post_script = NULL,
                         inputs = list(),
                         output = "object",
                         files = NULL,
                         depends = NULL,
                         name = NULL) {
  output <- .tp_match_output(output)
  .tp_assert_script(script, "script", must_exist = TRUE)

  e <- new.env(parent = globalenv())
  for (nm in names(inputs)) assign(nm, inputs[[nm]], envir = e)

  restore_env <- .tp_with_cpp_build_env()
  on.exit(restore_env(), add = TRUE)

  code <- .tp_cpp_source_code(script, depends)
  Rcpp::sourceCpp(code = code, env = e, verbose = FALSE)

  # Per-step Rcout/Rcerr logging (see tar_polyglot_log(), polyglot_controller()).
  log_cfg <- .tp_log_get_config()
  log_paths <- .tp_log_prepare(log_cfg, name)
  if (!is.null(log_paths) && isTRUE(log_cfg$header)) {
    .tp_log_write_header(
      log_paths$stdout, name = name, toolchain = "C++",
      version = paste0("Rcpp ", as.character(utils::packageVersion("Rcpp"))),
      tool_path = R.home("bin"),
      env_info = .tp_cpp_env_info(depends)
    )
  }

  .tp_cpp_with_redirect(log_paths$stdout, log_paths$stderr, function() {
    .tp_cpp_finish(e, post_script, output, files)
  })
}

# Build the C++ source text sourceCpp() should compile: the script's own code
# (from a file or an inline tar_code() source), prefixed with one
# `// [[Rcpp::depends(pkg)]]` attribute line per entry in `depends` (if any) --
# ahead of the user's own code, so it augments rather than replaces any
# `Rcpp::depends()` attribute already written in the script itself.
.tp_cpp_source_code <- function(script, depends) {
  code <- if (inherits(script, "tp_source")) script$code else
    paste(readLines(script, warn = FALSE), collapse = "\n")
  if (is.null(depends) || !length(depends)) {
    return(code)
  }
  header <- paste0("// [[Rcpp::depends(", depends, ")]]", collapse = "\n")
  paste(header, code, sep = "\n")
}

#' Compile a C++ step once for reuse across branches (worker behind tarpolyglot_map)
#'
#' Compiles the `// [[Rcpp::export]]` functions in a C++ script with [Rcpp::sourceCpp()] and returns a self-contained bundle that [run_cpp_step_prebuilt()] can reload in any branch without recompiling. This is the function the companion `<name>_cpp_lib` target built by `tar_target_cpp(..., pattern = tarpolyglot_map(...))` calls; it is exported so the call resolves at run time, but package users should not call it directly.
#'
#' Unlike [compile_rs_lib()], the bundle does **not** embed ready-to-call R closures: Rcpp's generated wrapper functions capture a raw compiled-routine pointer at the moment they are bound to a loaded library (`Rcpp:::sourceCppFunction()`, confirmed by inspecting the `.cpp.R` file `sourceCpp()` generates alongside the compiled library), unlike rextendr's wrappers, which resolve their routine by name from a named `PACKAGE=` at *call* time. A pointer captured in one process is meaningless in another (or even in the same process after the original library is unloaded), so a closure built here could not simply be reused after being carried to a different `crew` worker. Instead this bundle embeds the compiled library's bytes *and* the generated R wrapper source text (with its `dyn.load()` call still pointing at this process's build path); [run_cpp_step_prebuilt()] rewrites that path to wherever it re-materialises the library and re-evaluates the wrapper source there, which re-binds fresh, valid closures in the new process without recompiling.
#'
#' @inheritParams run_cpp_step
#' @inheritSection tarpolyglot-shared-params Script arguments
#'
#' @return An object of class `tp_cpp_lib`: a list with the library `basename`, the raw library `bytes`, the generated wrapper `wrapper_src` (character vector of R source lines), the `orig_path` the wrapper source's `dyn.load()` call originally pointed at (rewritten on reload), and `objs_names` (the exported function names, from `sourceCpp()`'s own `$functions`).
#' @seealso [tarpolyglot_map()], [run_cpp_step_prebuilt()], [tar_target_cpp()]
#' @keywords internal
#' @export
#' @examples
#' # Compiling needs a C++ compiler reachable by R, so this is gated on
#' # TARPOLYGLOT_EXAMPLES=true and runs in a temporary directory.
#' if (identical(Sys.getenv("TARPOLYGLOT_EXAMPLES"), "true")) {
#'   targets::tar_dir({
#'     # Normally invoked by tar_target_cpp(pattern = tarpolyglot_map(...)).
#'     writeLines(
#'       c("#include <Rcpp.h>",
#'         "// [[Rcpp::export]]",
#'         "double square(double x) { return x * x; }"),
#'       "square.cpp"
#'     )
#'     lib <- compile_cpp_lib(script = "square.cpp")
#'     class(lib)
#'   })
#' }
compile_cpp_lib <- function(script, depends = NULL) {
  .tp_assert_script(script, "script", must_exist = TRUE)

  restore_env <- .tp_with_cpp_build_env()
  on.exit(restore_env(), add = TRUE)

  code <- .tp_cpp_source_code(script, depends)
  e <- new.env(parent = globalenv())
  res <- Rcpp::sourceCpp(code = code, env = e, verbose = FALSE)

  dll_path <- list.files(res$buildDirectory, pattern = "\\.(dll|so|dylib)$",
    full.names = TRUE, recursive = TRUE)
  if (length(dll_path) != 1L) {
    stop("Expected exactly one compiled library in the sourceCpp() build ",
      "directory, found ", length(dll_path), ".", call. = FALSE)
  }
  r_path <- list.files(res$buildDirectory, pattern = "\\.cpp\\.R$",
    full.names = TRUE, recursive = TRUE)
  if (length(r_path) != 1L) {
    stop("Expected exactly one generated wrapper .cpp.R file in the sourceCpp() ",
      "build directory, found ", length(r_path), ".", call. = FALSE)
  }

  dll_path <- normalizePath(dll_path, winslash = "/", mustWork = TRUE)
  wrapper_src <- readLines(r_path, warn = FALSE)
  bytes <- readBin(dll_path, what = "raw", n = file.info(dll_path)$size)

  structure(
    list(
      basename = basename(dll_path),
      bytes = bytes,
      wrapper_src = wrapper_src,
      orig_path = dll_path,
      objs_names = res$functions
    ),
    class = "tp_cpp_lib"
  )
}

#' Run a C++ step from a pre-compiled library (worker behind tarpolyglot_map)
#'
#' Reloads a compiled C++ library produced by [compile_cpp_lib()] (writing the embedded shared library to a temporary file, then re-evaluating the embedded wrapper source so it binds fresh, valid closures against *this* process's copy -- see [compile_cpp_lib()] for why that is necessary, unlike Rust's [run_rs_step_prebuilt()]), then evaluates the R **post-script** exactly as [run_cpp_step()] does, with the compiled functions and the named `inputs` in scope. This is the function each branch target built by `tar_target_cpp(..., pattern = tarpolyglot_map(...))` calls; it is exported so the call resolves at run time, but package users should not call it directly.
#'
#' No C++ toolchain is needed here: reloading does not compile anything. See [tarpolyglot_map()] for the overall design.
#'
#' @inheritParams run_cpp_step
#' @inheritSection tarpolyglot-shared-params Script arguments
#' @param lib A `tp_cpp_lib` bundle from [compile_cpp_lib()] (supplied by the companion `<name>_cpp_lib` target).
#' @param name Character string, the branch's target name. Supplied automatically by the constructor; used only to name this branch's log files when [polyglot_controller()] was given a [tar_polyglot_log()] (`NULL` -- the default -- disables logging for a direct call). Note this is the branch name, not `<name>_cpp_lib` -- reloading a pre-compiled library never itself produces output to log.
#'
#' @return The value of the post-script (object mode) or a character vector of normalised file paths (file mode).
#' @seealso [tarpolyglot_map()], [compile_cpp_lib()], [run_cpp_step()]
#' @keywords internal
#' @export
#' @examples
#' # Reloading needs a library built by compile_cpp_lib(), which needs a C++
#' # compiler, so this is gated on TARPOLYGLOT_EXAMPLES=true.
#' if (identical(Sys.getenv("TARPOLYGLOT_EXAMPLES"), "true")) {
#'   targets::tar_dir({
#'     # Normally invoked by tar_target_cpp(pattern = tarpolyglot_map(...)).
#'     writeLines(
#'       c("#include <Rcpp.h>",
#'         "// [[Rcpp::export]]",
#'         "double square(double x) { return x * x; }"),
#'       "square.cpp"
#'     )
#'     writeLines("square(x)", "post.R")
#'     lib <- compile_cpp_lib(script = "square.cpp")
#'     run_cpp_step_prebuilt(lib = lib, inputs = list(x = 21), post_script = "post.R")
#'   })
#' }
run_cpp_step_prebuilt <- function(lib,
                                  post_script = NULL,
                                  inputs = list(),
                                  output = "object",
                                  files = NULL,
                                  name = NULL) {
  output <- .tp_match_output(output)
  if (!inherits(lib, "tp_cpp_lib")) {
    stop("`lib` must be a compiled library object from compile_cpp_lib().",
      call. = FALSE)
  }

  # sourceCpp() names each freshly compiled library `sourceCpp_<N>` from a
  # per-session counter, the same way rextendr numbers crates `rextendr<N>` --
  # so two different compile-once targets built in separate workers can
  # collide on the same registered name. Track which library (by content) is
  # currently bound under each name and rebuild the bindings when a different
  # one arrives, reusing them when the same library repeats (the common case
  # of many branches of one target on one worker then costs one rebind, not
  # one per branch).
  regname <- tools::file_path_sans_ext(lib$basename)
  cached <- .tp_cpplib_state[[regname]]
  if (is.null(cached) || !identical(cached$bytes, lib$bytes)) {
    loaded <- getLoadedDLLs()
    if (regname %in% names(loaded)) {
      try(dyn.unload(loaded[[regname]][["path"]]), silent = TRUE)
    }
    base <- file.path(tempdir(), "tarpolyglot-cpplib")
    dir.create(base, showWarnings = FALSE, recursive = TRUE)
    # A fresh unique subdirectory, not a fixed path: the previous copy may
    # still be locked (just unloaded, and an antivirus scanner may hold it),
    # which would fail an overwrite. The basename is kept so the registered
    # module name matches what the wrapper source's dyn.load() expects.
    sub <- tempfile("lib", tmpdir = base)
    dir.create(sub)
    path <- file.path(sub, lib$basename)
    writeBin(lib$bytes, path)
    path <- normalizePath(path, winslash = "/", mustWork = TRUE)

    # Rebind fresh wrapper closures against *this* copy: rewrite the
    # embedded wrapper source's dyn.load() target to the new path, then
    # re-evaluate it. This is the step compile_cpp_lib()'s docs describe --
    # it re-registers native symbols and rebuilds the R closures, but does
    # not recompile anything.
    new_src <- gsub(lib$orig_path, path, lib$wrapper_src, fixed = TRUE)
    bind_env <- new.env(parent = globalenv())
    eval(parse(text = new_src), envir = bind_env)
    objs <- stats::setNames(
      lapply(lib$objs_names, get, envir = bind_env),
      lib$objs_names
    )
    cached <- list(bytes = lib$bytes, objs = objs)
    .tp_cpplib_state[[regname]] <- cached
  }

  e <- new.env(parent = globalenv())
  for (nm in names(inputs)) assign(nm, inputs[[nm]], envir = e)
  for (nm in names(cached$objs)) assign(nm, cached$objs[[nm]], envir = e)

  # Per-step Rcout/Rcerr logging (see tar_polyglot_log(), polyglot_controller()).
  log_cfg <- .tp_log_get_config()
  log_paths <- .tp_log_prepare(log_cfg, name)
  if (!is.null(log_paths) && isTRUE(log_cfg$header)) {
    .tp_log_write_header(
      log_paths$stdout, name = name, toolchain = "C++",
      version = paste0("Rcpp ", as.character(utils::packageVersion("Rcpp"))),
      tool_path = R.home("bin"),
      env_info = "reused a pre-compiled library (tarpolyglot_map() compile-once), not recompiled"
    )
  }

  .tp_cpp_with_redirect(log_paths$stdout, log_paths$stderr, function() {
    .tp_cpp_finish(e, post_script, output, files)
  })
}
