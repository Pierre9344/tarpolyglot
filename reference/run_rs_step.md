# Execute a Rust step (worker behind tar_target_rs)

Compiles the `#[extendr]` functions in a Rust script with
[`rextendr::rust_source()`](https://extendr.github.io/rextendr/reference/rust_source.html),
exposing them as R functions in a fresh environment, then evaluates an R
**post-script** in that environment where you call those functions and
return the result. Upstream `inputs` are bound in the same environment.
This is the function the target built by
[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)
calls; it is exported so the call resolves at run time, but package
users should not call it directly.

## Usage

``` r
run_rs_step(
  script,
  post_script = NULL,
  inputs = list(),
  output = "object",
  files = NULL,
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

- post_script:

  Path to an R script evaluated after compilation. The compiled Rust
  functions and the named `inputs` are in scope; its last expression is
  the target value (object mode), or it returns a character vector of
  file paths (file mode). Required for object mode. Accepts a file path
  or an inline
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md)
  carrier; see the "Script arguments" section below.

- inputs:

  Named character vector (or list) mapping the name seen inside the step
  (in the R environment and, after the hand-off, in the foreign session)
  to the name of an upstream target, e.g. `c(x = "prepared_x")`. Each
  upstream target becomes a dependency of this target and is bound by
  that name in the step environment; under dynamic branching the
  per-branch slice is bound instead.

- output:

  Output mode: `"object"` (default) returns a converted R object,
  `"file"` returns a character vector of file paths (and defaults
  `format` to `"file"`).

- files:

  Optional character vector of file paths to return when no
  `post_script` is supplied in file mode.

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

The value of the post-script (object mode) or a character vector of
normalised file paths (file mode).

## Details

Unlike Python/Julia there is **no pre-script** for Rust and no live
interpreter: `rust_source()` compiles a dynamic library and R calls into
it with real type conversion (via [extendr](https://extendr.rs/)). A
Rust toolchain and `cargo` must be reachable (this function puts R,
cargo, and on Windows Rtools on `PATH` for the build itself); on Windows
use the GNU toolchain.

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

[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md),
[`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md),
[`run_jl_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_jl_step.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Normally invoked by tar_target_rs(); shown here as a direct call.
# scripts/square.rs:
#   #[extendr]
#   fn square(x: f64) -> f64 { x * x }
# scripts/post.R:
#   square(x)
run_rs_step(
  script = "scripts/square.rs",
  inputs = list(x = 21),
  post_script = "scripts/post.R"
)
} # }
```
