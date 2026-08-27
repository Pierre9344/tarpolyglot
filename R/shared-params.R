# Single source of truth for the arguments that mean exactly the same thing in every tarpolyglot constructor and worker. Other functions pull these with @inheritParams tarpolyglot-shared-params, so the wording can never drift. roxygen only copies params that are actual formals of the receiving function, so it is safe for the workers (which have only a subset) to inherit from here.
#
# The "Script options" section below is the single source of truth for how script arguments are supplied; constructors pull it in with @inheritSection so the three forms are described identically everywhere.

#' Shared arguments for tarpolyglot constructors and workers
#'
#' @param inputs Named character vector (or list) mapping the name seen inside the step (in the R environment and, after the hand-off, in the foreign session) to the name of an upstream target, e.g. `c(x = "prepared_x")`. Each upstream target becomes a dependency of this target and is bound by that name in the step environment; under dynamic branching the per-branch slice is bound instead.
#' @param output Output mode: `"object"` (default) returns a converted R object, `"file"` returns a character vector of file paths (and defaults `format` to `"file"`).
#' @param retrieve Optional character vector of foreign-session variable names to return when no `post_script` is supplied in object mode. One name returns that object; several return a named list.
#' @param files Optional character vector of file paths to return when no `post_script` is supplied in file mode.
#' @param packages,library Character vectors of R packages (and library paths) to load for the target, forwarded to [targets::tar_target_raw()].
#' @param deps,string Advanced [targets::tar_target_raw()] arguments: extra dependency names and a string used for change detection.
#' @param format,repository,iteration Storage/iteration settings forwarded to [targets::tar_target_raw()]. `format` defaults to `"file"` when `output = "file"`, otherwise to the `targets` option default.
#' @param error,memory,garbage_collection,deployment,priority,resources,storage,retrieval,cue,description Standard [targets::tar_target_raw()] execution/behaviour arguments, forwarded unchanged.
#'
#' @section Script options:
#'
#' Every script argument (`script`, and `pre_script` / `post_script` where the constructor has them) accepts the same three forms. The choice is not cosmetic: it decides whether editing the code re-runs the target.
#'
#' \describe{
#'   \item{A literal path string}{e.g. `script = "py/step.py"`. The file is read when the step runs, but it is **not** tracked, so editing it does **not** invalidate the target: `targets` will happily reuse a stale result until some *other* dependency changes. Simplest form, and a reasonable default once a script has settled.}
#'   \item{A [tar_target_path()] reference}{e.g. `script = tar_target_path("step_py")`, naming an upstream `tar_target(step_py, "py/step.py", format = "file")`. The file becomes a real `targets` dependency, so editing it **does** invalidate this target and the step re-runs. This is what you want while a script is still changing, and the recommended form for reproducible pipelines.}
#'   \item{Inline code via [tar_code()]}{e.g. `script = tar_code("result = sum(x)")`. The code lives in `_targets.R` rather than in a file, and is embedded in the target's command, so `targets` hashes it and editing it **does** invalidate the target. A character string carries foreign source (Python, Julia, Rust, C++) or R source; an R `{ ... }` block carries inline R and is accepted only by `pre_script` / `post_script`, never by the foreign `script`.}
#' }
#'
#' Mixing forms in one call is fine: a tracked `script` with a literal `post_script`, inline code for one and a file for another, and so on. See `vignette("scripts")` for worked examples of all three and guidance on choosing.
#'
#' @section Script arguments:
#'
#' A worker receives whatever the constructor already resolved, which is one of two things: a **path to a file** on disk, or an **inline carrier** built by [tar_code()] that holds the code in memory. Both are accepted, so a direct call may pass either.
#'
#' [tar_target_path()] is deliberately *not* a third form at this level. It is a constructor-level convenience: [tar_target_py()] and the other constructors rewrite it while the pipeline's DAG is built, so that by the time a worker runs it has already become the ordinary file path held by the upstream target. Handing the result of [tar_target_path()] straight to a worker therefore does not resolve to a file. The three forms as written in `_targets.R`, and which of them tracks your edits, are covered in `vignette("scripts")`.
#'
#' @name tarpolyglot-shared-params
#' @keywords internal
NULL

# `name` and `pattern` are the two arguments whose *meaning* changes between the
# character-based `_raw()` constructors and their non-standard-evaluation twins,
# so they cannot live in the block above. They are split along the two axes that
# actually vary:
#
#   * `name`    depends only on the form  (string vs symbol).
#   * `pattern` depends on the form *and* on the language: on Python/Julia the
#     tarpolyglot_*() helpers fall back to the plain targets patterns, while on
#     Rust/C++ they additionally compile the library once per pattern.
#
# Each wording is therefore defined once here and inherited, instead of being
# repeated across the four constructor files.

#' Target name argument for the character-based (`_raw`) constructors
#'
#' @param name Character string, the target name.
#'
#' @name tarpolyglot-params-raw
#' @keywords internal
NULL

#' Target name argument for the non-standard-evaluation constructors
#'
#' @param name Symbol, the target name (unquoted).
#'
#' @name tarpolyglot-params-nse
#' @keywords internal
NULL

#' Branching pattern for the interpreted-language `_raw` constructors
#'
#' @param pattern Optional \pkg{targets} dynamic-branching pattern as a language object (e.g. `quote(map(x))`), forwarded to [targets::tar_target_raw()]. The [tarpolyglot_map()] family is also accepted and behaves identically to the plain `targets` patterns here (they only differ on the Rust constructor).
#'
#' @name tarpolyglot-pattern-raw-interpreted
#' @keywords internal
NULL

#' Branching pattern for the interpreted-language NSE constructors
#'
#' @param pattern Optional dynamic-branching pattern, unquoted (e.g. `map(x)`).
#'
#' @name tarpolyglot-pattern-nse-interpreted
#' @keywords internal
NULL

#' Branching pattern for the compiled-language `_raw` constructors
#'
#' @param pattern Optional branching pattern as described in the [targets package documentation](https://books.ropensci.org/targets/dynamic.html#patterns), as a language object (e.g. `quote(map(x))`), forwarded to [targets::tar_target_raw()]. The patterns included in the \pkg{targets} package (`map()`, `head()`, ...) are accepted, but it is recommended to use the \pkg{tarpolyglot} pattern functions instead, as they compile the library once and reuse it across the branches (see [tarpolyglot_map()], [tarpolyglot_head()], [tarpolyglot_tail()], [tarpolyglot_cross()], [tarpolyglot_slice()], [tarpolyglot_sample()]).
#'
#' @name tarpolyglot-pattern-raw-compiled
#' @keywords internal
NULL

#' Post-script argument for the compiled-language constructors
#'
#' Rust and C++ share the same post-script contract: there is no pre-script and
#' no live interpreter, so the compiled functions are called from an R script
#' run after the build. Python and Julia differ (they have a pre-script and an
#' interpreter hand-off), so they keep their own wording.
#'
#' @param post_script Path to an R script run after compilation, where the compiled functions and `inputs` are in scope. Its last expression is the value (object mode); it returns file paths (file mode). Required for object mode. Accepts a literal path, a [tar_target_path()] reference, or inline code from [tar_code()]; see the "Script options" section below.
#'
#' @name tarpolyglot-post-script-compiled
#' @keywords internal
NULL

#' Branching pattern for the compiled-language NSE constructors
#'
#' @param pattern Optional branching pattern as described in the [targets package documentation](https://books.ropensci.org/targets/dynamic.html#patterns), unquoted (e.g. `map(x)`). The patterns included in the \pkg{targets} package (`map()`, `head()`, ...) are accepted, but it is recommended to use the \pkg{tarpolyglot} pattern functions instead, as they compile the library once and reuse it across the branches (see [tarpolyglot_map()], [tarpolyglot_head()], [tarpolyglot_tail()], [tarpolyglot_cross()], [tarpolyglot_slice()], [tarpolyglot_sample()]).
#'
#' @name tarpolyglot-pattern-nse-compiled
#' @keywords internal
NULL
