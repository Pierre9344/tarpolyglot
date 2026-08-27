# Run a C++ step from a pre-compiled library (worker behind tarpolyglot_map)

Reloads a compiled C++ library produced by
[`compile_cpp_lib()`](https://pierre9344.github.io/tarpolyglot/reference/compile_cpp_lib.md)
(writing the embedded shared library to a temporary file, then
re-evaluating the embedded wrapper source so it binds fresh, valid
closures against *this* process's copy – see
[`compile_cpp_lib()`](https://pierre9344.github.io/tarpolyglot/reference/compile_cpp_lib.md)
for why that is necessary, unlike Rust's
[`run_rs_step_prebuilt()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step_prebuilt.md)),
then evaluates the R **post-script** exactly as
[`run_cpp_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_cpp_step.md)
does, with the compiled functions and the named `inputs` in scope. This
is the function each branch target built by
`tar_target_cpp(..., pattern = tarpolyglot_map(...))` calls; it is
exported so the call resolves at run time, but package users should not
call it directly.

## Usage

``` r
run_cpp_step_prebuilt(
  lib,
  post_script = NULL,
  inputs = list(),
  output = "object",
  files = NULL,
  name = NULL
)
```

## Arguments

- lib:

  A `tp_cpp_lib` bundle from
  [`compile_cpp_lib()`](https://pierre9344.github.io/tarpolyglot/reference/compile_cpp_lib.md)
  (supplied by the companion `<name>_cpp_lib` target).

- post_script:

  Path to an R script evaluated after compilation. The compiled C++
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

- name:

  Character string, the branch's target name. Supplied automatically by
  the constructor; used only to name this branch's log files when
  [`polyglot_controller()`](https://pierre9344.github.io/tarpolyglot/reference/polyglot_controller.md)
  was given a
  [`tar_polyglot_log()`](https://pierre9344.github.io/tarpolyglot/reference/tar_polyglot_log.md)
  (`NULL` – the default – disables logging for a direct call). Note this
  is the branch name, not `<name>_cpp_lib` – reloading a pre-compiled
  library never itself produces output to log.

## Value

The value of the post-script (object mode) or a character vector of
normalised file paths (file mode).

## Details

No C++ toolchain is needed here: reloading does not compile anything.
See
[`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md)
for the overall design.

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
[`compile_cpp_lib()`](https://pierre9344.github.io/tarpolyglot/reference/compile_cpp_lib.md),
[`run_cpp_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_cpp_step.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Normally invoked by tar_target_cpp(pattern = tarpolyglot_map(...)).
# scripts/square.cpp:
#   // [[Rcpp::export]]
#   double square(double x) { return x * x; }
# scripts/post.R:
#   square(x)
lib <- compile_cpp_lib(script = "scripts/square.cpp")
run_cpp_step_prebuilt(lib = lib, inputs = list(x = 21), post_script = "scripts/post.R")
} # }
```
