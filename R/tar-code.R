# Inline-code marker for tarpolyglot steps. `tar_code()` lets `script` /
# `pre_script` / `post_script` carry code written directly in `_targets.R`
# instead of a path on disk, mirroring how `targets::tar_target(command = {...})`
# takes an inline block. It is the inline sibling of `tar_target_path()`.

#' Inline code for a tarpolyglot step
#'
#' Use in place of a file-path string (or a [tar_target_path()] reference) for the
#' `script`, `pre_script`, or `post_script` argument of the `tar_target_py()` /
#' `tar_target_jl()` / `tar_target_rs()` constructors (and their `_raw` forms), to
#' supply the code inline instead of pointing at a file.
#'
#' `tar_code()` accepts two forms. An R `{...}` block is captured as inline R code and is only valid in an R slot (`pre_script` or `post_script`); passing a block as the foreign `script` is an error. Anything that evaluates to a single character string is treated as inline source code, and its language follows from the slot it fills: the foreign `script` slot is Python, Julia, or Rust source, while a `pre_script` or `post_script` slot is R source.
#'
#' Multi-line strings are supported and preserved verbatim, then **dedented**: the
#' common leading-whitespace margin shared by all lines is stripped (and leading/
#' trailing blank lines dropped), so code you indent to line up with the surrounding
#' `_targets.R` still starts flush-left. This matters for Python, whose top-level
#' indentation is significant; Julia/Rust/R are unaffected either way. For Python or
#' regex payloads, prefer an R raw string `r"( ... )"` so backslashes and quotes need
#' no escaping.
#'
#' Because the inline code is embedded in the target's command, `targets` hashes it:
#' editing inline code re-runs the target automatically (unlike a literal path string,
#' which is untracked).
#'
#' @param x Inline code: an R `{...}` block, or an expression/variable/literal that
#'   yields a single character string of source code.
#' @return A classed marker (`tp_inline`) recognised by the `tar_target_*` constructors.
#' @seealso [tar_target_path()], [tar_target_py()], [tar_target_jl()], [tar_target_rs()]
#' @export
#' @examples
#' \dontrun{
#' # Inline R (pre/post) plus a one-line inline Python `script`:
#' tarpolyglot::tar_target_py(
#'   name        = m,
#'   inputs      = c(x = "prepared_x"),
#'   pre_script  = tar_code({ to_py <- list(x = x) }),   # inline R
#'   script      = tar_code("result = float(sum(x))"),   # inline Python
#'   post_script = tar_code({ py_get("result") })
#' )
#'
#' # Multi-line inline Python. Indent the code to line up with `_targets.R`;
#' # tar_code() dedents it, so Python's own block indentation stays correct.
#' tarpolyglot::tar_target_py(
#'   name   = pos_sum,
#'   inputs = c(x = "prepared_x"),
#'   script = tar_code(r"(
#'     result = 0
#'     for v in x:
#'         if v > 0:
#'             result += v
#'   )")
#' )
#' }
tar_code <- function(x) {
  expr <- substitute(x)
  # A brace block is inline R, captured unevaluated (valid only in pre/post slots).
  if (is.call(expr) && identical(expr[[1L]], as.name("{"))) {
    return(.tp_inline_expr(expr))
  }
  # Otherwise force the promise (in the caller's frame) to get its value: a string
  # literal, a variable holding a string, or any expression yielding one.
  value <- x
  if (!is.character(value) || length(value) != 1L || is.na(value)) {
    stop("`tar_code()` expects inline code: an R `{ }` block, or a single string ",
      "of source code.", call. = FALSE)
  }
  .tp_inline_source(.tp_dedent(value))
}

# Internal carriers built by tar_code() at construction time. They are NOT exported:
# `.tp_script_expr()` embeds an equivalent base-R `structure()` call into the target
# command, so nothing here needs to resolve at pipeline run time. `.tp_inline_source`
# holds a string of source code; `.tp_inline_expr` holds an unevaluated R expression.
.tp_inline_source <- function(code) {
  if (!is.character(code) || length(code) != 1L || is.na(code)) {
    stop("inline source must be a single string.", call. = FALSE)
  }
  structure(list(code = code), class = c("tp_inline", "tp_source"))
}

.tp_inline_expr <- function(expr) {
  structure(list(code = expr), class = c("tp_inline", "tp_expr"))
}

# Strip the common leading-whitespace margin from a (possibly multi-line) string, and
# drop leading/trailing blank lines. Preserves *relative* indentation (e.g. a Python
# loop body) while removing the margin added to align code with surrounding R source.
# Whitespace characters are compared, not expanded: a line whose leading whitespace
# differs in tabs-vs-spaces simply shortens the common prefix (matching textwrap.dedent).
.tp_dedent <- function(code) {
  lines <- strsplit(code, "\n", fixed = TRUE)[[1L]]
  if (length(lines) == 0L) return("")
  is_blank <- grepl("^[[:space:]]*$", lines)
  keep <- which(!is_blank)
  if (length(keep) == 0L) return("")
  lines <- lines[keep[1L]:keep[length(keep)]]
  is_blank <- is_blank[keep[1L]:keep[length(keep)]]

  # Longest common leading-whitespace (spaces/tabs) prefix over the non-blank lines.
  nb <- lines[!is_blank]
  prefixes <- sub("^([ \t]*).*$", "\\1", nb)
  common <- prefixes[1L]
  for (p in prefixes[-1L]) {
    common <- .tp_common_prefix(common, p)
    if (!nzchar(common)) break
  }

  n <- nchar(common)
  out <- vapply(seq_along(lines), function(i) {
    if (is_blank[i]) return("")
    if (n > 0L && startsWith(lines[i], common)) substring(lines[i], n + 1L) else lines[i]
  }, character(1L))
  paste(out, collapse = "\n")
}

# Longest common character prefix of two strings.
.tp_common_prefix <- function(a, b) {
  m <- min(nchar(a), nchar(b))
  if (m == 0L) return("")
  ca <- substring(a, seq_len(m), seq_len(m))
  cb <- substring(b, seq_len(m), seq_len(m))
  diff <- which(ca != cb)
  if (length(diff)) substr(a, 1L, diff[1L] - 1L) else substr(a, 1L, m)
}
