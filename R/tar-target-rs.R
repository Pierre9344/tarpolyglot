#' Target that runs a Rust script (raw / factory form)
#'
#' Character-based constructor mirroring [targets::tar_target_raw()] for Rust, for use inside targets factories. Returns a single `targets` target whose command compiles the `#[extendr]` functions in `script` with [rextendr::rust_source()] and then evaluates an R **post-script** that calls those functions (with the upstream `inputs` in scope) and returns the value. See [run_rs_step()] for the contract. For direct use in `_targets.R`, see [tar_target_rs()].
#'
#' Unlike Python/Julia there is **no pre-script** for Rust: inputs are used directly in the post-script alongside the compiled functions. A Rust toolchain and `cargo` are required; on Windows use the GNU toolchain (see `vignette("rust")`).
#'
#' Under dynamic branching, `pattern = map(...)` recompiles the crate in every branch (Rust has no live interpreter to reuse). Passing a tarpolyglot pattern helper instead ([tarpolyglot_map()], [tarpolyglot_cross()], [tarpolyglot_slice()], [tarpolyglot_head()], [tarpolyglot_tail()], [tarpolyglot_sample()]) compiles the crate **once** in a companion target named `<name>_rust_lib` and reuses it across all branches; the constructor then returns *both* targets as a list. See [tarpolyglot_map()].
#'
#' @inheritParams tarpolyglot-shared-params
#' @inheritSection tarpolyglot-shared-params Script options
#' @inheritParams tarpolyglot-params-raw
#' @inheritParams tarpolyglot-pattern-raw-compiled
#' @param script Path to the Rust script with `#[extendr]` functions (required). Accepts a literal path, a [tar_target_path()] reference, or inline code from [tar_code()]; see the "Script options" section below.
#' @inheritParams tarpolyglot-post-script-compiled
#' @param dependencies,features,profile Passed to [rextendr::rust_source()]: crate `dependencies` (named list), Cargo `features`, and build `profile`.
#' @param toolchain Optional rustup toolchain (e.g. `"stable-x86_64-pc-windows-gnu"`); sets `RUSTUP_TOOLCHAIN` for the build.
#'
#' @return A `targets` target object. When `pattern` uses [tarpolyglot_map()] it is instead a list of two targets: the `<name>_rust_lib` compile target and the branched `<name>` target.
#' @seealso [tar_target_rs()], [tarpolyglot_map()], [run_rs_step()], [tar_target_py_raw()], [tar_target_jl_raw()]
#' @export
#' @examples
#' # Building a target does not run it, so these examples need no Rust toolchain.
#' # scripts/square.rs:
#' #   #[extendr]
#' #   fn square(x: f64) -> f64 { x * x }
#' # scripts/post.R:
#' #   square(x)
#' tarpolyglot::tar_target_rs_raw(
#'   name = "rs_square",
#'   script = "scripts/square.rs",
#'   inputs = c(x = "value"),
#'   post_script = "scripts/post.R"
#' )
#'
#' # The three ways to supply a script (see the "Script options" section):
#' # 1. Literal path: untracked, editing the file does NOT re-run the step.
#' tarpolyglot::tar_target_rs_raw(
#'   name = "demo_literal", script = "rs/step.rs", post_script = "R/post.R"
#' )
#'
#' # 2. tar_target_path(): tracked, editing the file DOES re-run the step.
#' list(
#'   targets::tar_target(step_rs, "rs/step.rs", format = "file"),
#'   tarpolyglot::tar_target_rs_raw(
#'     name = "demo_tracked",
#'     script = tarpolyglot::tar_target_path("step_rs"),
#'     post_script = "R/post.R"
#'   )
#' )
#'
#' # 3. tar_code(): inline, editing the code DOES re-run the step. A string
#' #    carries foreign source; an R { } block carries inline R.
#' tarpolyglot::tar_target_rs_raw(
#'   name = "demo_inline",
#'   script = tarpolyglot::tar_code("#[extendr] fn one() -> f64 { 1.0 }"),
#'   post_script = tarpolyglot::tar_code({ one() })
#' )
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
  pinfo <- .tp_pattern(pattern)

  if (is.null(format)) {
    format <- if (identical(output, "file")) {
      "file"
    } else {
      targets::tar_option_get("format")
    }
  }

  # tarpolyglot_map() (etc.): compile the crate once in a companion
  # `<name>_rust_lib` target, then reuse it across the branches of `<name>`.
  if (isTRUE(pinfo$compile_once)) {
    return(.tp_rs_compile_once(
      name = name, script = script, post_script = post_script,
      inputs_call = inputs_call, output = output, files = files,
      dependencies = dependencies, features = features, profile = profile,
      toolchain = toolchain, pattern = pinfo$pattern, packages = packages,
      library = library, deps = deps, string = string, format = format,
      repository = repository, iteration = iteration, error = error,
      memory = memory, garbage_collection = garbage_collection,
      deployment = deployment, priority = priority, resources = resources,
      storage = storage, retrieval = retrieval, cue = cue,
      description = description
    ))
  }

  # Default path: a single target that (re)compiles in each branch, if any.
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

  targets::tar_target_raw(
    name = name,
    command = command,
    pattern = pinfo$pattern,
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

# Build the two-target compile-once expansion for tar_target_rs_raw():
#   * `<name>_rust_lib`: compiles the extendr crate once (not branched);
#   * `<name>`: branches over `pattern`, reusing the compiled library.
# Returns a list of both targets (targets flattens nested target lists).
.tp_rs_compile_once <- function(name, script, post_script, inputs_call, output,
                                files, dependencies, features, profile, toolchain,
                                pattern, packages, library, deps, string, format,
                                repository, iteration, error, memory,
                                garbage_collection, deployment, priority,
                                resources, storage, retrieval, cue, description) {
  lib_name <- paste0(name, "_rust_lib")

  lib_command <- bquote(
    tarpolyglot::compile_rs_lib(
      script = .(.tp_script_expr(script)),
      dependencies = .(dependencies),
      features = .(features),
      profile = .(profile),
      toolchain = .(toolchain)
    )
  )

  lib_description <- if (length(description) && !is.na(description) &&
      nzchar(description)) {
    paste0(description, " (Rust crate compiled once)")
  } else {
    paste0("Compile the Rust crate once for ", name)
  }

  lib_target <- targets::tar_target_raw(
    name = lib_name,
    command = lib_command,
    pattern = NULL,
    packages = packages,
    library = library,
    repository = repository,
    error = error,
    memory = memory,
    garbage_collection = garbage_collection,
    deployment = deployment,
    priority = priority,
    resources = resources,
    storage = storage,
    retrieval = retrieval,
    cue = cue,
    description = lib_description
  )

  branch_command <- bquote(
    tarpolyglot::run_rs_step_prebuilt(
      lib = .(as.name(lib_name)),
      post_script = .(.tp_script_expr(post_script)),
      inputs = .(inputs_call),
      output = .(output),
      files = .(files)
    )
  )

  branch_target <- targets::tar_target_raw(
    name = name,
    command = branch_command,
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

  list(lib_target, branch_target)
}

#' Target that runs a Rust script
#'
#' Non-standard-evaluation constructor mirroring [targets::tar_target()] for Rust: pass a bare `name` and unquoted `pattern`, for direct use in `_targets.R`. Compiles the `#[extendr]` functions in `script` with [rextendr::rust_source()] and calls them from the R `post_script`. Delegates to [tar_target_rs_raw()]; see it and [run_rs_step()] for the full reference. The Python/Julia twins are [tar_target_py()] / [tar_target_jl()].
#'
#' @inheritParams tarpolyglot-params-nse
#' @inheritParams tarpolyglot-pattern-nse-compiled
#' @inheritParams tar_target_rs_raw
#' @inheritSection tarpolyglot-shared-params Script options
#'
#' @return A `targets` target object. When `pattern` uses [tarpolyglot_map()] it is instead a list of two targets: the `<name>_rust_lib` compile target and the branched `<name>` target.
#' @seealso [tar_target_rs_raw()], [tarpolyglot_map()], [run_rs_step()], [tar_target_py()], [tar_target_jl()]
#' @export
#' @examples
#' # Building a target does not run it, so these examples need no Rust toolchain.
#' # scripts/square.rs:
#' #   #[extendr]
#' #   fn square(x: f64) -> f64 { x * x }
#' # scripts/post.R:
#' #   square(x)
#' list(
#'   tarpolyglot::tar_target_rs(
#'     name = rs_square,
#'     script = "scripts/square.rs",
#'     inputs = c(x = "value"),
#'     post_script = "scripts/post.R"
#'   )
#' )
#'
#' # The three ways to supply a script (see the "Script options" section):
#' # 1. Literal path: untracked, editing the file does NOT re-run the step.
#' tarpolyglot::tar_target_rs(
#'   name = demo_literal, script = "rs/step.rs", post_script = "R/post.R"
#' )
#'
#' # 2. tar_target_path(): tracked, editing the file DOES re-run the step.
#' list(
#'   targets::tar_target(step_rs, "rs/step.rs", format = "file"),
#'   tarpolyglot::tar_target_rs(
#'     name = demo_tracked,
#'     script = tarpolyglot::tar_target_path("step_rs"),
#'     post_script = "R/post.R"
#'   )
#' )
#'
#' # 3. tar_code(): inline, editing the code DOES re-run the step. A string
#' #    carries foreign source; an R { } block carries inline R.
#' tarpolyglot::tar_target_rs(
#'   name = demo_inline,
#'   script = tarpolyglot::tar_code("#[extendr] fn one() -> f64 { 1.0 }"),
#'   post_script = tarpolyglot::tar_code({ one() })
#' )
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
