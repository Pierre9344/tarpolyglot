# Single source of truth for the arguments that mean exactly the same thing in every tarpolyglot constructor and worker. Other functions pull these with @inheritParams tarpolyglot-shared-params, so the wording can never drift. roxygen only copies params that are actual formals of the receiving function, so it is safe for the workers (which have only a subset) to inherit from here.

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
#' @name tarpolyglot-shared-params
#' @keywords internal
NULL
