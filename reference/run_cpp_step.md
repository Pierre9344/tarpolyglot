# Execute a C++ step (worker behind tar_target_cpp)

Compiles the `// [[Rcpp::export]]` functions in a C++ script with
[`Rcpp::sourceCpp()`](https://rdrr.io/pkg/Rcpp/man/sourceCpp.html),
exposing them as R functions in a fresh environment, then evaluates an R
**post-script** in that environment where you call those functions and
return the result. Upstream `inputs` are bound in the same environment.
This is the function the target built by
[`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md)
calls; it is exported so the call resolves at run time, but package
users should not call it directly.

## Usage

``` r
run_cpp_step(
  script,
  post_script = NULL,
  inputs = list(),
  output = "object",
  files = NULL,
  depends = NULL,
  name = NULL
)
```

## Arguments

- script:

  Path to the C++ script containing `// [[Rcpp::export]]` functions
  (required). Accepts a file path or an inline
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md)
  carrier; see the "Script arguments" section below.

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

- depends:

  Optional character vector of extension packages (e.g.
  `c("RcppArmadillo", "RcppEigen")`), passed straight through as
  `// [[Rcpp::depends(...)]]` would be. Usually unnecessary: declaring
  `// [[Rcpp::depends(pkgname)]]` directly in the C++ source (the normal
  Rcpp convention) already works, so this argument is only useful if you
  would rather not repeat that in the source itself.

- name:

  Character string, the step's target name. Supplied automatically by
  the constructor; used only to name this step's log files when
  [`polyglot_controller()`](https://pierre9344.github.io/tarpolyglot/reference/polyglot_controller.md)
  was given a
  [`tar_polyglot_log()`](https://pierre9344.github.io/tarpolyglot/reference/tar_polyglot_log.md)
  (`NULL` – the default – disables logging for a direct call). Only
  `Rcpp::Rcout`/`Rcpp::Rcerr` output from the post-script's calls into
  compiled code is captured; see
  [`tar_polyglot_log()`](https://pierre9344.github.io/tarpolyglot/reference/tar_polyglot_log.md).

## Value

The value of the post-script (object mode) or a character vector of
normalised file paths (file mode).

## Details

Unlike Python/Julia there is **no pre-script** for C++ and no live
interpreter: `sourceCpp()` compiles a shared library and R calls into it
with real type conversion (via [Rcpp](https://www.rcpp.org/)).
Header-only extension packages such as RcppArmadillo/RcppEigen need no
special handling: declare them with a `// [[Rcpp::depends(pkgname)]]`
attribute directly in the C++ source, exactly as in any other Rcpp
usage, and `sourceCpp()` picks it up. `sourceCpp()` compiles via R's own
configured toolchain (`R CMD SHLIB`), so, unlike Rust, there is no
separate compiler/ABI to match – on Windows this function still puts
Rtools on `PATH` for the build itself, since a bare or `crew`-worker
process may not otherwise have it there.

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

[`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md),
[`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md),
[`run_jl_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_jl_step.md),
[`run_rs_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step.md)

## Examples

``` r
# This worker compiles C++, so it only runs when TARPOLYGLOT_EXAMPLES=true
# says a compiler reachable by R is available. tar_dir() runs the code in a
# temporary directory.
if (identical(Sys.getenv("TARPOLYGLOT_EXAMPLES"), "true")) {
  targets::tar_dir({
    # Normally invoked by tar_target_cpp(); shown here as a direct call.
    writeLines(
      c("#include <Rcpp.h>",
        "// [[Rcpp::export]]",
        "double square(double x) { return x * x; }"),
      "square.cpp"
    )
    writeLines("square(x)", "post.R")
    run_cpp_step(
      script = "square.cpp",
      inputs = list(x = 21),
      post_script = "post.R"
    )
  })
}
```
