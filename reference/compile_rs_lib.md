# Compile a Rust step once for reuse across branches (worker behind tarpolyglot_map)

Compiles the `#[extendr]` functions in a Rust script with
[`rextendr::rust_source()`](https://extendr.github.io/rextendr/reference/rust_source.html)
and returns a self-contained bundle (the compiled shared library plus
its generated R wrappers) that
[`run_rs_step_prebuilt()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step_prebuilt.md)
can reload in any branch without recompiling. This is the function the
companion `<name>_rust_lib` target built by
`tar_target_rs(..., pattern = tarpolyglot_map(...))` calls; it is
exported so the call resolves at run time, but package users should not
call it directly.

## Usage

``` r
compile_rs_lib(
  script,
  dependencies = NULL,
  features = NULL,
  profile = NULL,
  toolchain = NULL
)
```

## Arguments

- script:

  Path to the Rust script containing `#[extendr]` functions (required).

- dependencies, features, profile:

  Passed to
  [`rextendr::rust_source()`](https://extendr.github.io/rextendr/reference/rust_source.html):
  crate `dependencies` (named list), Cargo `features`, and build
  `profile` (e.g. `"dev"` or `"release"`).

- toolchain:

  Optional rustup toolchain (e.g. `"stable-x86_64-pc-windows-gnu"`);
  sets `RUSTUP_TOOLCHAIN` for the build. Default `NULL` uses the rustup
  default toolchain.

## Value

An object of class `tp_rust_lib`: a list with the library `basename`,
the raw library `bytes`, and the generated wrapper `objs` (named list of
R functions).

## Details

The bundle embeds the library bytes, so it travels with the target's
value to any worker or machine, and reloading is a
[`dyn.load()`](https://rdrr.io/r/base/dynload.html) (near-instant)
rather than a fresh `cargo` build. See
[`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md)
for the motivation and
[`run_rs_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step.md)
for the per-branch (recompiling) alternative.

## See also

[`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md),
[`run_rs_step_prebuilt()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step_prebuilt.md),
[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Normally invoked by tar_target_rs(pattern = tarpolyglot_map(...)).
lib <- compile_rs_lib(script = "scripts/square.rs")
} # }
```
