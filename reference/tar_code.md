# Inline code for a tarpolyglot step

Use in place of a file-path string (or a
[`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
reference) for the `script`, `pre_script`, or `post_script` argument of
the
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md)
/
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md)
/
[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)
constructors (and their `_raw` forms), to supply the code inline instead
of pointing at a file.

## Usage

``` r
tar_code(x)
```

## Arguments

- x:

  Inline code: an R `{...}` block, or an expression/variable/literal
  that yields a single character string of source code.

## Value

A classed marker (`tp_inline`) recognised by the `tar_target_*`
constructors.

## Details

`tar_code()` accepts two forms. An R `{...}` block is captured as inline
R code and is only valid in an R slot (`pre_script` or `post_script`);
passing a block as the foreign `script` is an error. Anything that
evaluates to a single character string is treated as inline source code,
and its language follows from the slot it fills: the foreign `script`
slot is Python, Julia, or Rust source, while a `pre_script` or
`post_script` slot is R source.

Multi-line strings are supported and preserved verbatim, then
**dedented**: the common leading-whitespace margin shared by all lines
is stripped (and leading/ trailing blank lines dropped), so code you
indent to line up with the surrounding `_targets.R` still starts
flush-left. This matters for Python, whose top-level indentation is
significant; Julia/Rust/R are unaffected either way. For Python or regex
payloads, prefer an R raw string `r"( ... )"` so backslashes and quotes
need no escaping.

Because the inline code is embedded in the target's command, `targets`
hashes it: editing inline code re-runs the target automatically (unlike
a literal path string, which is untracked).

## See also

[`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md),
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md),
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md),
[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Inline R (pre/post) plus a one-line inline Python `script`:
tarpolyglot::tar_target_py(
  name        = m,
  inputs      = c(x = "prepared_x"),
  pre_script  = tar_code({ to_py <- list(x = x) }),   # inline R
  script      = tar_code("result = float(sum(x))"),   # inline Python
  post_script = tar_code({ py_get("result") })
)

# Multi-line inline Python. Indent the code to line up with `_targets.R`;
# tar_code() dedents it, so Python's own block indentation stays correct.
tarpolyglot::tar_target_py(
  name   = pos_sum,
  inputs = c(x = "prepared_x"),
  script = tar_code(r"(
    result = 0
    for v in x:
        if v > 0:
            result += v
  )")
)
} # }
```
