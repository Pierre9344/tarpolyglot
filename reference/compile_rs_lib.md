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
  Accepts a file path or an inline
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md)
  carrier; see the "Script arguments" section below.

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

## Script arguments

A worker receives whatever the constructor already resolved, which is
one of two things: a **path to a file** on disk, or an **inline
carrier** built by
[`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md)
that holds the code in memory. Both are accepted, so a direct call may
pass either.

[`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
is deliberately *not* a third form at this level. It is a
constructor-level convenience:
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md)
and the other constructors rewrite it while the pipeline's DAG is built,
so that by the time a worker runs it has already become the ordinary
file path held by the upstream target. Handing the result of
[`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
straight to a worker therefore does not resolve to a file. The three
forms as written in `_targets.R`, and which of them tracks your edits,
are covered in
[`vignette("scripts")`](https://pierre9344.github.io/tarpolyglot/articles/scripts.md).

## See also

[`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md),
[`run_rs_step_prebuilt()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step_prebuilt.md),
[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)

## Examples

``` r
# Compiling needs a Rust toolchain, so this is gated on
# TARPOLYGLOT_EXAMPLES=true and runs in a temporary directory.
if (identical(Sys.getenv("TARPOLYGLOT_EXAMPLES"), "true")) {
  targets::tar_dir({
    # Normally invoked by tar_target_rs(pattern = tarpolyglot_map(...)).
    writeLines("#[extendr] fn square(x: f64) -> f64 { x * x }", "square.rs")
    lib <- compile_rs_lib(script = "square.rs")
    class(lib)
  })
}
```
