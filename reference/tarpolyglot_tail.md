# Dynamic-branching tail that compiles Rust once

A drop-in replacement for the targets
[`targets::tar_target()`](https://docs.ropensci.org/targets/reference/tar_target.html)
pattern helper [`tail()`](https://rdrr.io/r/utils/head.html), for use
unquoted in the `pattern` argument of a tarpolyglot constructor. Like
[`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md),
on
[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)
it compiles the extendr crate **once** in a companion `<name>_rust_lib`
target and reuses it across the kept branches; on
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md)
/
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md)
it is exactly [`tail()`](https://rdrr.io/r/utils/head.html). See
[`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md)
for the full explanation and the compile-once mechanics.

## Usage

``` r
tarpolyglot_tail(..., n)
```

## Arguments

- ...:

  Upstream target(s) to branch over, with the same meaning as in the
  targets [`tail()`](https://rdrr.io/r/utils/head.html) pattern.

- n:

  Number of branches to keep from the end, as in the targets
  [`tail()`](https://rdrr.io/r/utils/head.html) pattern.

## Value

This function is a marker consumed by the tarpolyglot constructors and
is not meant to be evaluated on its own; calling it directly raises an
error.

## See also

[`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md),
[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md),
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md),
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tarpolyglot::tar_target_rs(
  name = rs_last, script = "square.rs", inputs = c(x = "vals"),
  post_script = "post.R", pattern = tarpolyglot_tail(vals, n = 2)
)
} # }
```
