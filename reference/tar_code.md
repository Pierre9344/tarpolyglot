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

  Inline code: an R [`{ }`](https://rdrr.io/r/base/Paren.html) block, or
  an expression/variable/literal that yields a single character string
  of source code.

## Value

A classed marker (`tp_inline`) recognised by the `tar_target_*`
constructors.

## Details

The capture rule is: **an R [`{ }`](https://rdrr.io/r/base/Paren.html)
block is inline R (an expression); anything that evaluates to a single
string is inline source code.** Which language a string is interpreted
as follows from the slot it sits in – the foreign `script` slot means
Python/Julia/Rust source; a `pre_script`/`post_script` slot means R
source. An R [`{ }`](https://rdrr.io/r/base/Paren.html) block is only
valid in the R slots (`pre_script`/`post_script`); passing one as the
foreign `script` is an error.

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
list(
  tarpolyglot::tar_target_py(
    name        = m,
    inputs      = c(x = "prepared_x"),
    pre_script  = tar_code({ to_py <- list(x = x) }),   # inline R
    script      = tar_code("result = float(sum(x))"),   # inline Python
    post_script = tar_code({ py_get("result") })
  )
)
} # }
```
