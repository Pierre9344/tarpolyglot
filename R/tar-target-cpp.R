#' Target that runs a C++ script (raw / factory form)
#'
#' Character-based constructor mirroring [targets::tar_target_raw()] for C++, for use inside targets factories. Returns a single `targets` target whose command compiles the `// [[Rcpp::export]]` functions in `script` with [Rcpp::sourceCpp()] and then evaluates an R **post-script** that calls those functions (with the upstream `inputs` in scope) and returns the value. See [run_cpp_step()] for the contract. For direct use in `_targets.R`, see [tar_target_cpp()].
#'
#' Unlike Python/Julia there is **no pre-script** for C++: inputs are used directly in the post-script alongside the compiled functions, mirroring [tar_target_rs()]. A working C++ compiler is required; `sourceCpp()` compiles via R's own configured toolchain (`R CMD SHLIB`), so, unlike Rust, there is no separate compiler/ABI to match -- on Windows Rtools must be installed and discoverable the same way it already needs to be for any R package with compiled code.
#'
#' Under dynamic branching, `pattern = map(...)` recompiles the library in every branch (C++ has no live interpreter to reuse, the same limitation Rust has). Passing a tarpolyglot pattern helper instead ([tarpolyglot_map()], [tarpolyglot_cross()], [tarpolyglot_slice()], [tarpolyglot_head()], [tarpolyglot_tail()], [tarpolyglot_sample()]) compiles the library **once** in a companion target named `<name>_cpp_lib` and reuses it across all branches; the constructor then returns *both* targets as a list. See [tarpolyglot_map()].
#'
#' @inheritParams tarpolyglot-shared-params
#' @inheritSection tarpolyglot-shared-params Script options
#' @param name Character string, the target name.
#' @param script Path to the C++ script with `// [[Rcpp::export]]` functions (required). Accepts a literal path, a [tar_target_path()] reference, or inline code from [tar_code()]; see the "Script options" section below.
#' @param post_script Path to an R script run after compilation, where the compiled functions and `inputs` are in scope. Its last expression is the value (object mode); it returns file paths (file mode). Required for object mode. Accepts a literal path, a [tar_target_path()] reference, or inline code from [tar_code()]; see the "Script options" section below.
#' @param depends Optional character vector of extension packages (e.g. `c("RcppArmadillo", "RcppEigen")`); see [run_cpp_step()].
#' @param pattern Optional branching pattern as described in the [targets package documentation](https://books.ropensci.org/targets/dynamic.html#patterns), as a language object (e.g. `quote(map(x))`), forwarded to [targets::tar_target_raw()]. The patterns included in the \pkg{targets} package (`map()`, `head()`, ...) are accepted, but it is recommended to use the \pkg{tarpolyglot} pattern functions instead, as they compile the library once and reuse it across the branches (see [tarpolyglot_map()], [tarpolyglot_head()], [tarpolyglot_tail()], [tarpolyglot_cross()], [tarpolyglot_slice()], [tarpolyglot_sample()]).
#'
#' @return A `targets` target object. When `pattern` uses [tarpolyglot_map()] it is instead a list of two targets: the `<name>_cpp_lib` compile target and the branched `<name>` target.
#' @seealso [tar_target_cpp()], [tarpolyglot_map()], [run_cpp_step()], [tar_target_rs_raw()], [tar_target_py_raw()], [tar_target_jl_raw()]
#' @export
#' @examples
#' \dontrun{
#' # scripts/square.cpp:
#' #   // [[Rcpp::export]]
#' #   double square(double x) { return x * x; }
#' # scripts/post.R:
#' #   square(x)
#' tarpolyglot::tar_target_cpp_raw(
#'   name = "cpp_square",
#'   script = "scripts/square.cpp",
#'   inputs = c(x = "value"),
#'   post_script = "scripts/post.R"
#' )
#'
#' # The three ways to supply a script (see the "Script options" section):
#' # 1. Literal path: untracked, editing the file does NOT re-run the step.
#' tarpolyglot::tar_target_cpp_raw(
#'   name = "demo_literal", script = "cpp/step.cpp", post_script = "R/post.R"
#' )
#'
#' # 2. tar_target_path(): tracked, editing the file DOES re-run the step.
#' list(
#'   targets::tar_target(step_cpp, "cpp/step.cpp", format = "file"),
#'   tarpolyglot::tar_target_cpp_raw(
#'     name = "demo_tracked",
#'     script = tarpolyglot::tar_target_path("step_cpp"),
#'     post_script = "R/post.R"
#'   )
#' )
#'
#' # 3. tar_code(): inline, editing the code DOES re-run the step. A string
#' #    carries foreign source; an R { } block carries inline R.
#' tarpolyglot::tar_target_cpp_raw(
#'   name = "demo_inline",
#'   script = tarpolyglot::tar_code(
#'     "// [[Rcpp::export]]\nint one() { return 1; }"
#'   ),
#'   post_script = tarpolyglot::tar_code({ one() })
#' )
#' }
tar_target_cpp_raw <- function(name,
                               script,
                               post_script = NULL,
                               inputs = NULL,
                               output = "object",
                               files = NULL,
                               depends = NULL,
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
    stop("`script` cannot be an R `tar_code({ ... })` block; the C++ `script` ",
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

  # tarpolyglot_map() (etc.): compile the library once in a companion
  # `<name>_cpp_lib` target, then reuse it across the branches of `<name>`.
  if (isTRUE(pinfo$compile_once)) {
    return(.tp_cpp_compile_once(
      name = name, script = script, post_script = post_script,
      inputs_call = inputs_call, output = output, files = files,
      depends = depends, pattern = pinfo$pattern, packages = packages,
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
    tarpolyglot::run_cpp_step(
      script = .(.tp_script_expr(script)),
      post_script = .(.tp_script_expr(post_script)),
      inputs = .(inputs_call),
      output = .(output),
      files = .(files),
      depends = .(depends),
      name = .(name)
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

# Build the two-target compile-once expansion for tar_target_cpp_raw():
#   * `<name>_cpp_lib`: compiles the C++ library once (not branched);
#   * `<name>`: branches over `pattern`, reusing the compiled library.
# Returns a list of both targets (targets flattens nested target lists).
# Mirrors .tp_rs_compile_once() in tar-target-rs.R (kept as a separate copy
# rather than a cross-file refactor, to avoid touching the already-shipped
# Rust implementation while this is developed in isolation).
.tp_cpp_compile_once <- function(name, script, post_script, inputs_call, output,
                                 files, depends, pattern, packages, library, deps,
                                 string, format, repository, iteration, error,
                                 memory, garbage_collection, deployment, priority,
                                 resources, storage, retrieval, cue, description) {
  lib_name <- paste0(name, "_cpp_lib")

  lib_command <- bquote(
    tarpolyglot::compile_cpp_lib(
      script = .(.tp_script_expr(script)),
      depends = .(depends)
    )
  )

  lib_description <- if (length(description) && !is.na(description) &&
      nzchar(description)) {
    paste0(description, " (C++ library compiled once)")
  } else {
    paste0("Compile the C++ library once for ", name)
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
    tarpolyglot::run_cpp_step_prebuilt(
      lib = .(as.name(lib_name)),
      post_script = .(.tp_script_expr(post_script)),
      inputs = .(inputs_call),
      output = .(output),
      files = .(files),
      name = .(name)
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

#' Target that runs a C++ script
#'
#' Non-standard-evaluation constructor mirroring [targets::tar_target()] for C++: pass a bare `name` and unquoted `pattern`, for direct use in `_targets.R`. Compiles the `// [[Rcpp::export]]` functions in `script` with [Rcpp::sourceCpp()] and calls them from the R `post_script`. Delegates to [tar_target_cpp_raw()]; see it and [run_cpp_step()] for the full reference. The Rust twin is [tar_target_rs()]; Python/Julia are [tar_target_py()] / [tar_target_jl()].
#'
#' @inheritParams tar_target_cpp_raw
#' @inheritSection tarpolyglot-shared-params Script options
#' @param name Symbol, the target name (unquoted).
#' @param pattern Optional branching pattern as described in the [targets package documentation](https://books.ropensci.org/targets/dynamic.html#patterns), unquoted (e.g. `map(x)`). The patterns included in the \pkg{targets} package (`map()`, `head()`, ...) are accepted, but it is recommended to use the \pkg{tarpolyglot} pattern functions instead, as they compile the library once and reuse it across the branches (see [tarpolyglot_map()], [tarpolyglot_head()], [tarpolyglot_tail()], [tarpolyglot_cross()], [tarpolyglot_slice()], [tarpolyglot_sample()]).
#'
#' @return A `targets` target object. When `pattern` uses [tarpolyglot_map()] it is instead a list of two targets: the `<name>_cpp_lib` compile target and the branched `<name>` target.
#' @seealso [tar_target_cpp_raw()], [tarpolyglot_map()], [run_cpp_step()], [tar_target_rs()], [tar_target_py()], [tar_target_jl()]
#' @export
#' @examples
#' \dontrun{
#' # scripts/square.cpp:
#' #   // [[Rcpp::export]]
#' #   double square(double x) { return x * x; }
#' # scripts/post.R:
#' #   square(x)
#' list(
#'   tarpolyglot::tar_target_cpp(
#'     name = cpp_square,
#'     script = "scripts/square.cpp",
#'     inputs = c(x = "value"),
#'     post_script = "scripts/post.R"
#'   )
#' )
#'
#' # The three ways to supply a script (see the "Script options" section):
#' # 1. Literal path: untracked, editing the file does NOT re-run the step.
#' tarpolyglot::tar_target_cpp(
#'   name = demo_literal, script = "cpp/step.cpp", post_script = "R/post.R"
#' )
#'
#' # 2. tar_target_path(): tracked, editing the file DOES re-run the step.
#' list(
#'   targets::tar_target(step_cpp, "cpp/step.cpp", format = "file"),
#'   tarpolyglot::tar_target_cpp(
#'     name = demo_tracked,
#'     script = tarpolyglot::tar_target_path("step_cpp"),
#'     post_script = "R/post.R"
#'   )
#' )
#'
#' # 3. tar_code(): inline, editing the code DOES re-run the step. A string
#' #    carries foreign source; an R { } block carries inline R.
#' tarpolyglot::tar_target_cpp(
#'   name = demo_inline,
#'   script = tarpolyglot::tar_code(
#'     "// [[Rcpp::export]]\nint one() { return 1; }"
#'   ),
#'   post_script = tarpolyglot::tar_code({ one() })
#' )
#' }
tar_target_cpp <- function(name,
                           script,
                           post_script = NULL,
                           inputs = NULL,
                           output = "object",
                           files = NULL,
                           depends = NULL,
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
  tar_target_cpp_raw(
    name = name,
    script = script,
    post_script = post_script,
    inputs = inputs,
    output = output,
    files = files,
    depends = depends,
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
