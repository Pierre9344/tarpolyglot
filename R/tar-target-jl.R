#' Target that runs a Julia script (raw / factory form)
#'
#' Character-based constructor mirroring [targets::tar_target_raw()]: `name` is a string and it is meant for use *inside targets factories*. Returns a single `targets` target whose command runs an optional R pre-script, `script` (via \pkg{JuliaCall}), and an optional R post-script, then returns a converted R object or a character vector of files. See [run_jl_step()] for the pre/post-script contract (the `to_jl` hand-off and the `jl_get` / `jl_call` helpers). For direct use in `_targets.R`, see [tar_target_jl()]. The Python twin is [tar_target_py_raw()].
#'
#' All [targets::tar_target_raw()] arguments are forwarded unchanged, so dynamic branching (`pattern`), storage `format`, `deployment`, `resources`, `cue`, etc. all work as usual. Upstream targets are wired in through `inputs`, which become dependencies (and are sliced under dynamic branching).
#'
#' @inheritParams tarpolyglot-shared-params
#' @inheritSection tarpolyglot-shared-params Script options
#' @param name Character string, the target name.
#' @param script Path to the Julia script to run (required). Accepts a literal path, a [tar_target_path()] reference, or inline code from [tar_code()]; see the "Script options" section below.
#' @param pre_script Optional path to an R script run before the Julia script. See [run_jl_step()]; assign a named list `to_jl` to hand objects to Julia. Accepts a literal path, a [tar_target_path()] reference, or inline code from [tar_code()]; see the "Script options" section below.
#' @param post_script Optional path to an R script run after the Julia script. See [run_jl_step()]; helpers `jl_get()` and `jl_call()` are available, and its last expression (object mode) or returned paths (file mode) become the value. Accepts a literal path, a [tar_target_path()] reference, or inline code from [tar_code()]; see the "Script options" section below.
#' @param julia_version Optional Julia version to select (e.g. `"1.11"`), used when `julia_home` is not given; resolved to a juliaup-managed install. Forwarded to [run_jl_step()]. Default `NULL` uses the computer/global Julia.
#' @param julia_home,julia_project,julia_packages Julia environment selection, forwarded to [run_jl_step()]. `julia_home` is the directory containing the julia executable (defaults to `getOption("tarpolyglot.julia_home")`; when unset and no `julia_version`, JuliaCall discovers Julia on `PATH`). `julia_project` is a Julia project environment to `Pkg.activate()`. `julia_packages` is a character vector of packages to `using` before the script.
#' @param pattern Optional \pkg{targets} dynamic-branching pattern as a language object (e.g. `quote(map(x))`), forwarded to [targets::tar_target_raw()]. The [tarpolyglot_map()] family is also accepted and behaves identically to the plain `targets` patterns here (they only differ on the Rust constructor).
#'
#' @return A `targets` target object.
#' @seealso [tar_target_jl()], [run_jl_step()], [tar_target_py_raw()]
#' @export
#' @examples
#' \dontrun{
#' # scripts/sum.jl (uses the `using Statistics` julia_packages requests):
#' #   result = mean(x)
#' # scripts/post.R:
#' #   jl_get("result")
#' tarpolyglot::tar_target_jl_raw(
#'   name = "jl_sum",
#'   script = "scripts/sum.jl",
#'   inputs = c(x = "prepared_x"),
#'   post_script = "scripts/post.R",
#'   julia_packages = "Statistics"
#' )
#'
#' # The three ways to supply a script (see the "Script options" section):
#' # 1. Literal path: untracked, editing the file does NOT re-run the step.
#' tarpolyglot::tar_target_jl_raw(
#'   name = "demo_literal", script = "jl/step.jl", retrieve = "result"
#' )
#'
#' # 2. tar_target_path(): tracked, editing the file DOES re-run the step.
#' list(
#'   targets::tar_target(step_jl, "jl/step.jl", format = "file"),
#'   tarpolyglot::tar_target_jl_raw(
#'     name = "demo_tracked",
#'     script = tarpolyglot::tar_target_path("step_jl"),
#'     retrieve = "result"
#'   )
#' )
#'
#' # 3. tar_code(): inline, editing the code DOES re-run the step. A string
#' #    carries foreign source; an R { } block carries inline R.
#' tarpolyglot::tar_target_jl_raw(
#'   name = "demo_inline",
#'   script = tarpolyglot::tar_code("result = 1 + 1"),
#'   post_script = tarpolyglot::tar_code({ jl_get("result") })
#' )
#'
#' # Tracking a helper file the script includes. Point `inputs` at a
#' # format = "file" target so editing the helper also re-runs the step;
#' # `inputs` takes the *target* name, not the path. Julia resolves a
#' # relative include() against the including file's own directory, so make
#' # the path absolute. jl/step.jl is then:
#' #   include(helper_path)
#' #   result = sum(myscale(x))
#' list(
#'   targets::tar_target(helper_file, "jl/helper.jl", format = "file"),
#'   tarpolyglot::tar_target_jl_raw(
#'     name = "demo_helper",
#'     script = "jl/step.jl",
#'     inputs = c(x = "prepared_x", helper_path = "helper_file"),
#'     pre_script = tarpolyglot::tar_code({
#'       to_jl <- list(x = x, helper_path = normalizePath(helper_path, winslash = "/"))
#'     }),
#'     retrieve = "result"
#'   )
#' )
#' }
tar_target_jl_raw <- function(name,
                              script,
                              pre_script = NULL,
                              post_script = NULL,
                              inputs = NULL,
                              output = "object",
                              retrieve = NULL,
                              files = NULL,
                              julia_version = NULL,
                              julia_home = getOption("tarpolyglot.julia_home"),
                              julia_project = NULL,
                              julia_packages = NULL,
                              pattern = NULL,
                              packages = targets::tar_option_get("packages"),
                              library = targets::tar_option_get("library"),
                              deps = NULL,
                              string = NULL,
                              format = NULL,
                              repository = targets::tar_option_get("repository"),
                              iteration = targets::tar_option_get("iteration"),
                              error = targets::tar_option_get("error"),
                              memory = targets::tar_option_get("memory"),
                              garbage_collection = isTRUE(targets::tar_option_get("garbage_collection")),
                              deployment = targets::tar_option_get("deployment"),
                              priority = targets::tar_option_get("priority"),
                              resources = targets::tar_option_get("resources"),
                              storage = targets::tar_option_get("storage"),
                              retrieval = targets::tar_option_get("retrieval"),
                              cue = targets::tar_option_get("cue"),
                              description = targets::tar_option_get("description")) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    stop("`name` must be a single non-empty string.", call. = FALSE)
  }
  output <- .tp_match_output(output)
  .tp_assert_script(script, "script")
  if (inherits(script, "tp_expr")) {
    stop("`script` cannot be an R `tar_code({ ... })` block; the Julia `script` ",
      "must be source code (a `tar_code(\"...\")` string) or a path.", call. = FALSE)
  }
  if (!is.null(pre_script)) .tp_assert_script(pre_script, "pre_script")
  if (!is.null(post_script)) .tp_assert_script(post_script, "post_script")
  inputs_call <- .tp_inputs_call(inputs)

  command <- bquote(
    tarpolyglot::run_jl_step(
      script = .(.tp_script_expr(script)),
      pre_script = .(.tp_script_expr(pre_script)),
      post_script = .(.tp_script_expr(post_script)),
      inputs = .(inputs_call),
      output = .(output),
      retrieve = .(retrieve),
      files = .(files),
      julia_version = .(julia_version),
      julia_home = .(julia_home),
      julia_project = .(julia_project),
      julia_packages = .(julia_packages),
      name = .(name)
    )
  )

  if (is.null(format)) {
    format <- if (identical(output, "file")) {
      "file"
    } else {
      targets::tar_option_get("format")
    }
  }

  targets::tar_target_raw(
    name = name,
    command = command,
    pattern = .tp_pattern(pattern)$pattern,
    packages = packages,
    library = library,
    deps = deps,
    string = string,
    format = format,
    repository = repository,
    iteration = iteration,
    error = error,
    memory = memory,
    garbage_collection = garbage_collection,
    deployment = deployment,
    priority = priority,
    resources = resources,
    storage = storage,
    retrieval = retrieval,
    cue = cue,
    description = description
  )
}

#' Target that runs a Julia script
#'
#' Non-standard-evaluation constructor mirroring [targets::tar_target()]: pass a bare `name` and unquoted `pattern`, for direct use in `_targets.R`. Delegates to [tar_target_jl_raw()]; see it and [run_jl_step()] for the full reference. The Python twin is [tar_target_py()].
#'
#' @inheritParams tar_target_jl_raw
#' @inheritSection tarpolyglot-shared-params Script options
#' @param name Symbol, the target name (unquoted).
#' @param pattern Optional dynamic-branching pattern, unquoted (e.g. `map(x)`).
#'
#' @return A `targets` target object.
#' @seealso [tar_target_jl_raw()], [run_jl_step()], [tar_target_py()]
#' @export
#' @examples
#' \dontrun{
#' # scripts/sum.jl:
#' #   result = sum(x)
#' # scripts/post.R:
#' #   jl_get("result")
#' list(
#'   tarpolyglot::tar_target_jl(
#'     name = jl_sum,
#'     script = "scripts/sum.jl",
#'     inputs = c(x = "prepared_x"),
#'     post_script = "scripts/post.R"
#'   )
#' )
#'
#' # The three ways to supply a script (see the "Script options" section):
#' # 1. Literal path: untracked, editing the file does NOT re-run the step.
#' tarpolyglot::tar_target_jl(
#'   name = demo_literal, script = "jl/step.jl", retrieve = "result"
#' )
#'
#' # 2. tar_target_path(): tracked, editing the file DOES re-run the step.
#' list(
#'   targets::tar_target(step_jl, "jl/step.jl", format = "file"),
#'   tarpolyglot::tar_target_jl(
#'     name = demo_tracked,
#'     script = tarpolyglot::tar_target_path("step_jl"),
#'     retrieve = "result"
#'   )
#' )
#'
#' # 3. tar_code(): inline, editing the code DOES re-run the step. A string
#' #    carries foreign source; an R { } block carries inline R.
#' tarpolyglot::tar_target_jl(
#'   name = demo_inline,
#'   script = tarpolyglot::tar_code("result = 1 + 1"),
#'   post_script = tarpolyglot::tar_code({ jl_get("result") })
#' )
#'
#' # Tracking a helper file the script includes. Point `inputs` at a
#' # format = "file" target so editing the helper also re-runs the step;
#' # `inputs` takes the *target* name, not the path. Julia resolves a
#' # relative include() against the including file's own directory, so make
#' # the path absolute. jl/step.jl is then:
#' #   include(helper_path)
#' #   result = sum(myscale(x))
#' list(
#'   targets::tar_target(helper_file, "jl/helper.jl", format = "file"),
#'   tarpolyglot::tar_target_jl(
#'     name = demo_helper,
#'     script = "jl/step.jl",
#'     inputs = c(x = "prepared_x", helper_path = "helper_file"),
#'     pre_script = tarpolyglot::tar_code({
#'       to_jl <- list(x = x, helper_path = normalizePath(helper_path, winslash = "/"))
#'     }),
#'     retrieve = "result"
#'   )
#' )
#' }
tar_target_jl <- function(name,
                          script,
                          pre_script = NULL,
                          post_script = NULL,
                          inputs = NULL,
                          output = "object",
                          retrieve = NULL,
                          files = NULL,
                          julia_version = NULL,
                          julia_home = getOption("tarpolyglot.julia_home"),
                          julia_project = NULL,
                          julia_packages = NULL,
                          pattern = NULL,
                          packages = targets::tar_option_get("packages"),
                          library = targets::tar_option_get("library"),
                          deps = NULL,
                          string = NULL,
                          format = NULL,
                          repository = targets::tar_option_get("repository"),
                          iteration = targets::tar_option_get("iteration"),
                          error = targets::tar_option_get("error"),
                          memory = targets::tar_option_get("memory"),
                          garbage_collection = isTRUE(targets::tar_option_get("garbage_collection")),
                          deployment = targets::tar_option_get("deployment"),
                          priority = targets::tar_option_get("priority"),
                          resources = targets::tar_option_get("resources"),
                          storage = targets::tar_option_get("storage"),
                          retrieval = targets::tar_option_get("retrieval"),
                          cue = targets::tar_option_get("cue"),
                          description = targets::tar_option_get("description")) {
  name <- .tp_name(substitute(name))
  pattern <- substitute(pattern)
  tar_target_jl_raw(
    name = name,
    script = script,
    pre_script = pre_script,
    post_script = post_script,
    inputs = inputs,
    output = output,
    retrieve = retrieve,
    files = files,
    julia_version = julia_version,
    julia_home = julia_home,
    julia_project = julia_project,
    julia_packages = julia_packages,
    pattern = pattern,
    packages = packages,
    library = library,
    deps = deps,
    string = string,
    format = format,
    repository = repository,
    iteration = iteration,
    error = error,
    memory = memory,
    garbage_collection = garbage_collection,
    deployment = deployment,
    priority = priority,
    resources = resources,
    storage = storage,
    retrieval = retrieval,
    cue = cue,
    description = description
  )
}
