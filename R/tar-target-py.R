#' Target that runs a Python script (raw / factory form)
#'
#' Character-based constructor mirroring [targets::tar_target_raw()]: `name` is a string and it is meant for use *inside targets factories*. Returns a single `targets` target whose command runs an optional R pre-script, `script` (via \pkg{reticulate}), and an optional R post-script, then returns a converted R object or a character vector of files. See [run_py_step()] for the pre/post-script contract (the `to_py` hand-off and the `py` / `py_get` helpers). For direct use in `_targets.R`, see [tar_target_py()]. The Julia twin is [tar_target_jl_raw()].
#'
#' All [targets::tar_target_raw()] arguments are forwarded unchanged, so dynamic branching (`pattern`), storage `format`, `deployment`, `resources`, `cue`, etc. all work as usual. Upstream targets are wired in through `inputs`, which become dependencies (and are sliced under dynamic branching).
#'
#' The interpreter/environment selection arguments (`python`, `env`, `env_manager`, `python_version`) are forwarded to [run_py_step()], which documents them (they are *alternatives*: normally set only one; precedence `python` > `env`/`env_manager` > `python_version` > none). See also `vignette("python")` for a decision guide with examples.
#'
#' @inheritParams tarpolyglot-shared-params
#' @inheritSection tarpolyglot-shared-params Script options
#' @inheritParams run_py_step
#' @param name Character string, the target name.
#' @param script Path to the Python script to run (required). Accepts a literal path, a [tar_target_path()] reference, or inline code from [tar_code()]; see the "Script options" section below.
#' @param pre_script Optional path to an R script run before the Python script. See [run_py_step()]; assign a named list `to_py` to hand objects to Python. Accepts a literal path, a [tar_target_path()] reference, or inline code from [tar_code()]; see the "Script options" section below.
#' @param post_script Optional path to an R script run after the Python script. See [run_py_step()]; helpers `py` and `py_get()` are available, and its last expression (object mode) or returned paths (file mode) become the value. Accepts a literal path, a [tar_target_path()] reference, or inline code from [tar_code()]; see the "Script options" section below.
#' @param pattern Optional \pkg{targets} dynamic-branching pattern as a language object (e.g. `quote(map(x))`), forwarded to [targets::tar_target_raw()]. The [tarpolyglot_map()] family is also accepted and behaves identically to the plain `targets` patterns here (they only differ on the Rust constructor).
#'
#' @return A `targets` target object.
#' @seealso [tar_target_py()], [run_py_step()], [tar_target_jl_raw()]
#' @export
#' @examples
#' \dontrun{
#' # Inside a targets factory:
#' # scripts/pre.R:
#' #   to_py <- list(x = x)
#' # scripts/sum.py:
#' #   result = sum(x)
#' # scripts/post.R:
#' #   py$result
#' tarpolyglot::tar_target_py_raw(
#'   name = "py_sum",
#'   script = "scripts/sum.py",
#'   inputs = c(x = "prepared_x"),
#'   pre_script = "scripts/pre.R",
#'   post_script = "scripts/post.R"
#' )
#'
#' # The three ways to supply a script (see the "Script options" section):
#' # 1. Literal path: untracked, editing the file does NOT re-run the step.
#' tarpolyglot::tar_target_py_raw(
#'   name = "demo_literal", script = "py/step.py", retrieve = "result"
#' )
#'
#' # 2. tar_target_path(): tracked, editing the file DOES re-run the step.
#' list(
#'   targets::tar_target(step_py, "py/step.py", format = "file"),
#'   tarpolyglot::tar_target_py_raw(
#'     name = "demo_tracked",
#'     script = tarpolyglot::tar_target_path("step_py"),
#'     retrieve = "result"
#'   )
#' )
#'
#' # 3. tar_code(): inline, editing the code DOES re-run the step. A string
#' #    carries foreign source; an R { } block carries inline R.
#' tarpolyglot::tar_target_py_raw(
#'   name = "demo_inline",
#'   script = tarpolyglot::tar_code("result = 1 + 1"),
#'   post_script = tarpolyglot::tar_code({ py_get("result") })
#' )
#'
#' # Tracking a helper module the script imports. Point `inputs` at a
#' # format = "file" target so editing the helper also re-runs the step;
#' # `inputs` takes the *target* name, not the path. py/step.py then loads
#' # the helper from the bound path rather than a hard-coded one:
#' #   import os, sys
#' #   sys.path.insert(0, os.path.dirname(helper_path))
#' #   import helper
#' #   result = sum(helper.scale(x))
#' list(
#'   targets::tar_target(helper_file, "py/helper.py", format = "file"),
#'   tarpolyglot::tar_target_py_raw(
#'     name = "demo_helper",
#'     script = "py/step.py",
#'     inputs = c(x = "prepared_x", helper_path = "helper_file"),
#'     pre_script = tarpolyglot::tar_code({
#'       to_py <- list(x = x, helper_path = helper_path)
#'     }),
#'     retrieve = "result"
#'   )
#' )
#' }
tar_target_py_raw <- function(name,
                              script,
                              pre_script = NULL,
                              post_script = NULL,
                              inputs = NULL,
                              output = "object",
                              retrieve = NULL,
                              files = NULL,
                              python_version = NULL,
                              env = NULL,
                              env_manager = "system",
                              python = NULL,
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
    stop("`script` cannot be an R `tar_code({ ... })` block; the Python `script` ",
      "must be source code (a `tar_code(\"...\")` string) or a path.", call. = FALSE)
  }
  if (!is.null(pre_script)) .tp_assert_script(pre_script, "pre_script")
  if (!is.null(post_script)) .tp_assert_script(post_script, "post_script")
  inputs_call <- .tp_inputs_call(inputs)

  command <- bquote(
    tarpolyglot::run_py_step(
      script = .(.tp_script_expr(script)),
      pre_script = .(.tp_script_expr(pre_script)),
      post_script = .(.tp_script_expr(post_script)),
      inputs = .(inputs_call),
      output = .(output),
      retrieve = .(retrieve),
      files = .(files),
      python_version = .(python_version),
      env = .(env),
      env_manager = .(env_manager),
      python = .(python),
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

#' Target that runs a Python script
#'
#' Non-standard-evaluation constructor mirroring [targets::tar_target()]: pass a bare `name` and an unquoted `pattern`, for direct use in `_targets.R`. It quotes those and delegates to [tar_target_py_raw()]. See that function and [run_py_step()] for the full argument reference and the pre/post-script contract. The Julia twin is [tar_target_jl()].
#'
#' @inheritParams tar_target_py_raw
#' @inheritSection tarpolyglot-shared-params Script options
#' @param name Symbol, the target name (unquoted).
#' @param pattern Optional dynamic-branching pattern, unquoted (e.g. `map(x)`).
#'
#' @return A `targets` target object.
#' @seealso [tar_target_py_raw()], [run_py_step()], [tar_target_jl()]
#' @export
#' @examples
#' \dontrun{
#' # Inside _targets.R:
#' # scripts/sum.py:
#' #   result = sum(x)
#' # scripts/post.R:
#' #   py$result
#' list(
#'   tarpolyglot::tar_target_py(
#'     name = py_sum,
#'     script = "scripts/sum.py",
#'     inputs = c(x = "prepared_x"),
#'     post_script = "scripts/post.R"
#'   )
#' )
#'
#' # The three ways to supply a script (see the "Script options" section):
#' # 1. Literal path: untracked, editing the file does NOT re-run the step.
#' tarpolyglot::tar_target_py(
#'   name = demo_literal, script = "py/step.py", retrieve = "result"
#' )
#'
#' # 2. tar_target_path(): tracked, editing the file DOES re-run the step.
#' list(
#'   targets::tar_target(step_py, "py/step.py", format = "file"),
#'   tarpolyglot::tar_target_py(
#'     name = demo_tracked,
#'     script = tarpolyglot::tar_target_path("step_py"),
#'     retrieve = "result"
#'   )
#' )
#'
#' # 3. tar_code(): inline, editing the code DOES re-run the step. A string
#' #    carries foreign source; an R { } block carries inline R.
#' tarpolyglot::tar_target_py(
#'   name = demo_inline,
#'   script = tarpolyglot::tar_code("result = 1 + 1"),
#'   post_script = tarpolyglot::tar_code({ py_get("result") })
#' )
#'
#' # Tracking a helper module the script imports. Point `inputs` at a
#' # format = "file" target so editing the helper also re-runs the step;
#' # `inputs` takes the *target* name, not the path. py/step.py then loads
#' # the helper from the bound path rather than a hard-coded one:
#' #   import os, sys
#' #   sys.path.insert(0, os.path.dirname(helper_path))
#' #   import helper
#' #   result = sum(helper.scale(x))
#' list(
#'   targets::tar_target(helper_file, "py/helper.py", format = "file"),
#'   tarpolyglot::tar_target_py(
#'     name = demo_helper,
#'     script = "py/step.py",
#'     inputs = c(x = "prepared_x", helper_path = "helper_file"),
#'     pre_script = tarpolyglot::tar_code({
#'       to_py <- list(x = x, helper_path = helper_path)
#'     }),
#'     retrieve = "result"
#'   )
#' )
#' }
tar_target_py <- function(name,
                          script,
                          pre_script = NULL,
                          post_script = NULL,
                          inputs = NULL,
                          output = "object",
                          retrieve = NULL,
                          files = NULL,
                          python_version = NULL,
                          env = NULL,
                          env_manager = "system",
                          python = NULL,
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
  tar_target_py_raw(
    name = name,
    script = script,
    pre_script = pre_script,
    post_script = post_script,
    inputs = inputs,
    output = output,
    retrieve = retrieve,
    files = files,
    python_version = python_version,
    env = env,
    env_manager = env_manager,
    python = python,
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
