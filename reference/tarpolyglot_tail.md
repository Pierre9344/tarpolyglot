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

## Only recognised by tarpolyglot constructors

The `tarpolyglot_*()` pattern helpers work only inside the `pattern`
argument of the tarpolyglot constructors
([`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md),
[`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md),
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md),
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md),
and their `_raw()` forms), which rewrite them to the plain targets
pattern before building the target. Used directly in a plain
[`targets::tar_target()`](https://docs.ropensci.org/targets/reference/tar_target.html)
or
[`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html)
they raise an error such as
`invalid dynamic branching pattern ... Illegal symbols found: tarpolyglot_map`,
because targets validates a pattern against its own fixed set of pattern
functions and does not know these helpers. This cannot be fixed from
tarpolyglot: targets looks its pattern functions up in a locked internal
environment, so teaching it a new one would require modifying the
targets package itself. In a plain targets target (which has no foreign
code to compile, so nothing to gain) use the native `map()` / `cross()`
/ `slice()` / [`head()`](https://rdrr.io/r/utils/head.html) /
[`tail()`](https://rdrr.io/r/utils/head.html) /
[`sample()`](https://rdrr.io/r/base/sample.html) instead.

## See also

The other pattern helpers:
[`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md),
[`tarpolyglot_cross()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_cross.md),
[`tarpolyglot_slice()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_slice.md),
[`tarpolyglot_head()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_head.md),
[`tarpolyglot_sample()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_sample.md).
The constructors that accept them:
[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md),
[`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md),
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md),
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# square.rs:
#   #[extendr]
#   fn square(x: f64) -> f64 { x * x }
# post.R:
#   square(x)
tarpolyglot::tar_target_rs(
  name = rs_last, script = "square.rs", inputs = c(x = "vals"),
  post_script = "post.R", pattern = tarpolyglot_tail(vals, n = 2)
)
} # }
```
