# Run a Rust step from a pre-compiled library (worker behind tarpolyglot_map)

Reloads a compiled Rust library produced by
[`compile_rs_lib()`](https://pierre9344.github.io/tarpolyglot/reference/compile_rs_lib.md)
(writing the embedded shared library to a temporary file and
[`dyn.load()`](https://rdrr.io/r/base/dynload.html)-ing it, then binding
the generated wrapper functions), then evaluates the R **post-script**
exactly as
[`run_rs_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step.md)
does, with the compiled functions and the named `inputs` in scope. This
is the function each branch target built by
`tar_target_rs(..., pattern = tarpolyglot_map(...))` calls; it is
exported so the call resolves at run time, but package users should not
call it directly.

## Usage

``` r
run_rs_step_prebuilt(
  lib,
  post_script = NULL,
  inputs = list(),
  output = "object",
  files = NULL
)
```

## Arguments

- lib:

  A `tp_rust_lib` bundle from
  [`compile_rs_lib()`](https://pierre9344.github.io/tarpolyglot/reference/compile_rs_lib.md)
  (supplied by the companion `<name>_rust_lib` target).

- post_script:

  Path to an R script evaluated after compilation. The compiled Rust
  functions and the named `inputs` are in scope; its last expression is
  the target value (object mode), or it returns a character vector of
  file paths (file mode). Required for object mode.

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

## Value

The value of the post-script (object mode) or a character vector of
normalised file paths (file mode).

## Details

No Rust toolchain is needed here: reloading is a
[`dyn.load()`](https://rdrr.io/r/base/dynload.html), not a build. See
[`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md)
for the overall design.

## See also

[`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md),
[`compile_rs_lib()`](https://pierre9344.github.io/tarpolyglot/reference/compile_rs_lib.md),
[`run_rs_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Normally invoked by tar_target_rs(pattern = tarpolyglot_map(...)).
lib <- compile_rs_lib(script = "scripts/square.rs")
run_rs_step_prebuilt(lib = lib, inputs = list(x = 21), post_script = "scripts/post.R")
} # }
```
