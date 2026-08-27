# Internal helpers shared by the Python and Julia step workers/constructors.

# Deparse a bare-symbol or string `name` captured with substitute().
.tp_name <- function(expr) {
  if (is.character(expr)) return(expr)
  deparse(expr)
}

# The user's home directory. On Windows R's path.expand("~") points at Documents, so prefer USERPROFILE / HOME for locating dotfile depots.
.tp_user_home <- function() {
  for (h in c(Sys.getenv("USERPROFILE"), Sys.getenv("HOME"))) {
    if (nzchar(h)) return(h)
  }
  path.expand("~")
}

# Evaluate an R pre/post step in `envir`, returning the value of its last top-level
# expression. base::sys.source() does not return the last value, so we parse and
# evaluate the expressions ourselves. This is what lets a post-script "return" the
# target's value simply by ending on that value. Accepts a file path (parsed from
# disk), an inline `tp_expr` R block (evaluated directly), or an inline `tp_source`
# string of R code (parsed from text).
.tp_eval_script <- function(x, envir) {
  if (inherits(x, "tp_expr")) {
    return(eval(x$code, envir = envir))
  }
  exprs <- if (inherits(x, "tp_source")) parse(text = x$code) else parse(file = x)
  value <- NULL
  for (i in seq_along(exprs)) {
    value <- eval(exprs[[i]], envir = envir)
  }
  value
}

#' Track a script argument as a `targets` dependency
#'
#' Use as the `script`, `pre_script`, or `post_script` argument of [tar_target_py()]/[tar_target_jl()]/[tar_target_rs()] (and their `_raw` forms) instead of a literal path string, to make that step re-run whenever the script file changes. `name` is the name of an upstream `targets` target (typically one created with `format = "file"` tracking the script file), and its *value* (the file path) is substituted in when the pipeline runs.
#'
#' This mirrors how `inputs = c(x = "some_target")` already wires an upstream target in by name: the target's name is given as a string, and the constructor turns it into a real dependency. A plain string passed directly as `script`/`pre_script`/`post_script` keeps meaning what it always has (an untracked literal path), so existing pipelines are unaffected.
#'
#' @param name Character string, the name of an upstream target whose value is the script's file path (e.g. a `tar_target(..., format = "file")`).
#' @return An object marking `name` for dependency-wiring by the `tar_target_*` constructors.
#' @seealso [tar_target_py()], [tar_target_jl()], [tar_target_rs()]
#' @examples
#' # Building a target does not run it, so this example needs no Python.
#' # python/fit_step.py:
#' #   result = sum(x)
#' # scripts/pre.R:
#' #   to_py <- list(x = x)
#' list(
#'   targets::tar_target(fit_pyscript, "python/fit_step.py", format = "file"),
#'   tar_target_py(
#'     name = fit,
#'     script = tar_target_path("fit_pyscript"),  # re-runs when the file changes
#'     pre_script = "scripts/pre.R",              # untracked literal path
#'     inputs = c(x = "prepared_x"),
#'     retrieve = "result"
#'   )
#' )
#' @export
tar_target_path <- function(name) {
  if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name)) {
    stop("`name` must be a single non-empty target-name string.", call. = FALSE)
  }
  structure(name, class = c("tp_target_ref", "character"))
}

# Turn a script/pre_script/post_script argument into the expression to splice into the target command: a `tar_target_path()` reference becomes a bare symbol (so `targets` records it as a dependency and substitutes the upstream target's value at run time); a `tar_code()` inline marker becomes a self-contained base-R `structure()` call that rebuilds the classed carrier at run time (source string, or R block wrapped in `quote()`), so the code lives in -- and is hashed with -- the command without referencing any tarpolyglot function; anything else (a literal string, or NULL for an absent pre/post-script) passes through unchanged, to be embedded as a constant exactly as before.
.tp_script_expr <- function(x) {
  if (inherits(x, "tp_target_ref")) return(as.name(unclass(x)))
  if (inherits(x, "tp_source")) {
    return(bquote(structure(list(code = .(x$code)), class = c("tp_inline", "tp_source"))))
  }
  if (inherits(x, "tp_expr")) {
    return(bquote(structure(list(code = quote(.(x$code))), class = c("tp_inline", "tp_expr"))))
  }
  x
}

# Validate that `path` is a single non-empty string (checked at construction time) and, when `must_exist`, that the file is present (checked at run time). A `tar_target_path()` reference has nothing to check yet at construction time (its value is only known once `targets` resolves the upstream target); by the time `must_exist` matters (run time), the command has already substituted in the upstream target's plain-string value, so this branch is authoring-time only.
.tp_assert_script <- function(path, arg, must_exist = FALSE) {
  if (inherits(path, "tp_target_ref")) {
    return(invisible(TRUE))
  }
  # An inline `tar_code()` marker carries its code in memory: nothing on disk to check.
  if (inherits(path, "tp_inline")) {
    return(invisible(TRUE))
  }
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("`", arg, "` must be a single non-empty file path, or a tar_target_path() reference.",
      call. = FALSE)
  }
  if (must_exist && !file.exists(path)) {
    stop("`", arg, "` points to a file that does not exist: ", path, call. = FALSE)
  }
  invisible(TRUE)
}

# Turn an `inputs` spec (named character vector / list mapping the name seen in R and in the foreign session -> upstream target name) into an unevaluated `list(nm = <symbol target>, ...)` call. Splicing this call into the target command (via bquote) keeps the upstream target names as bare symbols, so `targets` records them as dependencies and dynamic branching slices them.
.tp_inputs_call <- function(inputs) {
  if (is.null(inputs) || length(inputs) == 0L) {
    return(quote(list()))
  }
  inputs <- unlist(inputs, use.names = TRUE)
  nms <- names(inputs)
  if (is.null(nms) || !all(nzchar(nms))) {
    stop("`inputs` must be a *named* character vector/list mapping ",
      "in-session names to upstream target names, e.g. c(x = \"up_target\").",
      call. = FALSE)
  }
  syms <- lapply(unname(inputs), as.name)
  as.call(c(list(as.name("list")), stats::setNames(syms, nms)))
}

# Validate the small enumerations we accept.
.tp_match_output <- function(output) {
  match.arg(output, c("object", "file"))
}
