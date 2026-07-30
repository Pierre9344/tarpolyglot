#' Target that runs a Rust script (raw / factory form)
#'
#' Character-based constructor mirroring [targets::tar_target_raw()] for Rust, for use inside targets factories. Returns a single `targets` target whose command compiles the `#[extendr]` functions in `script` with [rextendr::rust_source()] and then evaluates an R **post-script** that calls those functions (with the upstream `inputs` in scope) and returns the value. See [run_rs_step()] for the contract. For direct use in `_targets.R`, see [tar_target_rs()].
#'
#' Unlike Python/Julia there is **no pre-script** for Rust: inputs are used directly in the post-script alongside the compiled functions. A Rust toolchain and `cargo` are required; on Windows use the GNU toolchain (see `vignette("rust")`).
#'
#' @inheritParams tarpolyglot-shared-params
#' @param name Character string, the target name.
#' @param script Path to the Rust script with `#[extendr]` functions (required). Either a literal string (an untracked path: editing the file does not invalidate the target) or a [tar_target_path()] reference to an upstream target (typically `format = "file"`), which makes this step re-run whenever that file changes.
#' @param post_script Path to an R script run after compilation, where the compiled functions and `inputs` are in scope. Its last expression is the value (object mode); it returns file paths (file mode). Required for object mode. Accepts a literal string or a [tar_target_path()] reference, as for `script`.
#' @param dependencies,features,profile Passed to [rextendr::rust_source()]: crate `dependencies` (named list), Cargo `features`, and build `profile`.
#' @param toolchain Optional rustup toolchain (e.g. `"stable-x86_64-pc-windows-gnu"`); sets `RUSTUP_TOOLCHAIN` for the build.
#' @param pattern Optional \pkg{targets} dynamic-branching pattern as a language object (e.g. `quote(map(x))`), forwarded to [targets::tar_target_raw()].
#'
#' @return A `targets` target object.
#' @seealso [tar_target_rs()], [run_rs_step()], [tar_target_py_raw()], [tar_target_jl_raw()]
#' @export
#' @examples
#' \dontrun{
#' tarpolyglot::tar_target_rs_raw(
#'   name = "rs_square",
#'   script = "scripts/square.rs",     # #[extendr] fn square(x: f64) -> f64
#'   inputs = c(x = "value"),
#'   post_script = "scripts/post.R"    # ends on square(x)
#' )
#' }
tar_target_rs_raw <- function(name,
                              script,
                              post_script = NULL,
                              inputs = NULL,
                              output = "object",
                              files = NULL,
                              dependencies = NULL,
                              features = NULL,
                              profile = NULL,
                              toolchain = NULL,
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
    stop("`script` cannot be an R `tar_code({ ... })` block; the Rust `script` ",
      "must be source code (a `tar_code(\"...\")` string) or a path.", call. = FALSE)
  }
  if (!is.null(post_script)) .tp_assert_script(post_script, "post_script")
  inputs_call <- .tp_inputs_call(inputs)

  command <- bquote(
    tarpolyglot::run_rs_step(
      script = .(.tp_script_expr(script)),
      post_script = .(.tp_script_expr(post_script)),
      inputs = .(inputs_call),
      output = .(output),
      files = .(files),
      dependencies = .(dependencies),
      features = .(features),
      profile = .(profile),
      toolchain = .(toolchain)
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

#' Target that runs a Rust script
#'
#' Non-standard-evaluation constructor mirroring [targets::tar_target()] for Rust: pass a bare `name` and unquoted `pattern`, for direct use in `_targets.R`. Compiles the `#[extendr]` functions in `script` with [rextendr::rust_source()] and calls them from the R `post_script`. Delegates to [tar_target_rs_raw()]; see it and [run_rs_step()] for the full reference. The Python/Julia twins are [tar_target_py()] / [tar_target_jl()].
#'
#' @inheritParams tar_target_rs_raw
#' @param name Symbol, the target name (unquoted).
#' @param pattern Optional dynamic-branching pattern, unquoted (e.g. `map(x)`).
#'
#' @return A `targets` target object.
#' @seealso [tar_target_rs_raw()], [run_rs_step()], [tar_target_py()], [tar_target_jl()]
#' @export
#' @examples
#' \dontrun{
#' list(
#'   tarpolyglot::tar_target_rs(
#'     name = rs_square,
#'     script = "scripts/square.rs",
#'     inputs = c(x = "value"),
#'     post_script = "scripts/post.R"
#'   )
#' )
#' }
tar_target_rs <- function(name,
                          script,
                          post_script = NULL,
                          inputs = NULL,
                          output = "object",
                          files = NULL,
                          dependencies = NULL,
                          features = NULL,
                          profile = NULL,
                          toolchain = NULL,
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
  tar_target_rs_raw(
    name = name,
    script = script,
    post_script = post_script,
    inputs = inputs,
    output = output,
    files = files,
    dependencies = dependencies,
    features = features,
    profile = profile,
    toolchain = toolchain,
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
