# Dynamic-branching map that compiles Rust/C++ once

A drop-in replacement for the targets
[`targets::tar_target()`](https://docs.ropensci.org/targets/reference/tar_target.html)
pattern helper `map()`, for use unquoted in the `pattern` argument of a
tarpolyglot constructor
([`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md),
[`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md),
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md),
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md),
and their `_raw` forms).

## Usage

``` r
tarpolyglot_map(...)
```

## Arguments

- ...:

  Upstream targets to map over in parallel, exactly as in the targets
  `map()` pattern (e.g. `tarpolyglot_map(x)` or
  `tarpolyglot_map(x, y)`).

## Value

This function is a marker consumed by the tarpolyglot constructors and
is not meant to be evaluated on its own; calling it directly raises an
error.

## Details

On
[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)
and
[`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md)
it changes how the branches are built: the crate/library is compiled
**once** in a companion target named `<name>_rust_lib` /
`<name>_cpp_lib`, and every branch reuses that compiled library instead
of recompiling. Recompiling per branch is otherwise the default, because
Rust and C++ have no live interpreter (contrast Python/Julia, whose
interpreter is simply reused). With three branches this turns roughly
`3 x compile` into `1 x compile + 3 x (near-instant reload)`.

On
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md)
and
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md)
there is nothing to compile, so `tarpolyglot_map()` is exactly `map()`:
it is provided so the same pipeline code can branch every language
uniformly.

Use it wherever you would write `map()`: `pattern = tarpolyglot_map(x)`.
The arguments are upstream target names to iterate over in parallel,
with the same meaning as
[`targets::tar_target()`](https://docs.ropensci.org/targets/reference/tar_target.html)'s
`map()`.

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
[`tarpolyglot_cross()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_cross.md),
[`tarpolyglot_slice()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_slice.md),
[`tarpolyglot_head()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_head.md),
[`tarpolyglot_tail()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_tail.md),
[`tarpolyglot_sample()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_sample.md).
The constructors that accept them:
[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md),
[`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md),
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md),
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# rs/square.rs:
#   #[extendr]
#   fn square(x: f64) -> f64 { x * x }
# R/post_square.R:
#   square(x)
list(
  tar_target(vals, c(10, 20, 30)),
  # Rust: compiles rs/square.rs once in `rs_branch_rust_lib`, then squares
  # each branch value reusing that compiled library.
  tarpolyglot::tar_target_rs(
    name = rs_branch,
    script = "rs/square.rs",
    inputs = c(x = "vals"),
    post_script = "R/post_square.R",
    pattern = tarpolyglot_map(vals)
  )
)
} # }
```
