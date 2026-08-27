# Compile a C++ step once for reuse across branches (worker behind tarpolyglot_map)

Compiles the `// [[Rcpp::export]]` functions in a C++ script with
[`Rcpp::sourceCpp()`](https://rdrr.io/pkg/Rcpp/man/sourceCpp.html) and
returns a self-contained bundle that
[`run_cpp_step_prebuilt()`](https://pierre9344.github.io/tarpolyglot/reference/run_cpp_step_prebuilt.md)
can reload in any branch without recompiling. This is the function the
companion `<name>_cpp_lib` target built by
`tar_target_cpp(..., pattern = tarpolyglot_map(...))` calls; it is
exported so the call resolves at run time, but package users should not
call it directly.

## Usage

``` r
compile_cpp_lib(script, depends = NULL)
```

## Arguments

- script:

  Path to the C++ script containing `// [[Rcpp::export]]` functions
  (required). Accepts a file path or an inline
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md)
  carrier; see the "Script arguments" section below.

- depends:

  Optional character vector of extension packages (e.g.
  `c("RcppArmadillo", "RcppEigen")`), passed straight through as
  `// [[Rcpp::depends(...)]]` would be. Usually unnecessary: declaring
  `// [[Rcpp::depends(pkgname)]]` directly in the C++ source (the normal
  Rcpp convention) already works, so this argument is only useful if you
  would rather not repeat that in the source itself.

## Value

An object of class `tp_cpp_lib`: a list with the library `basename`, the
raw library `bytes`, the generated wrapper `wrapper_src` (character
vector of R source lines), the `orig_path` the wrapper source's
[`dyn.load()`](https://rdrr.io/r/base/dynload.html) call originally
pointed at (rewritten on reload), and `objs_names` (the exported
function names, from `sourceCpp()`'s own `$functions`).

## Details

Unlike
[`compile_rs_lib()`](https://pierre9344.github.io/tarpolyglot/reference/compile_rs_lib.md),
the bundle does **not** embed ready-to-call R closures: Rcpp's generated
wrapper functions capture a raw compiled-routine pointer at the moment
they are bound to a loaded library (`Rcpp:::sourceCppFunction()`,
confirmed by inspecting the `.cpp.R` file `sourceCpp()` generates
alongside the compiled library), unlike rextendr's wrappers, which
resolve their routine by name from a named `PACKAGE=` at *call* time. A
pointer captured in one process is meaningless in another (or even in
the same process after the original library is unloaded), so a closure
built here could not simply be reused after being carried to a different
`crew` worker. Instead this bundle embeds the compiled library's bytes
*and* the generated R wrapper source text (with its
[`dyn.load()`](https://rdrr.io/r/base/dynload.html) call still pointing
at this process's build path);
[`run_cpp_step_prebuilt()`](https://pierre9344.github.io/tarpolyglot/reference/run_cpp_step_prebuilt.md)
rewrites that path to wherever it re-materialises the library and
re-evaluates the wrapper source there, which re-binds fresh, valid
closures in the new process without recompiling.

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
[`run_cpp_step_prebuilt()`](https://pierre9344.github.io/tarpolyglot/reference/run_cpp_step_prebuilt.md),
[`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Normally invoked by tar_target_cpp(pattern = tarpolyglot_map(...)).
# scripts/square.cpp:
#   // [[Rcpp::export]]
#   double square(double x) { return x * x; }
lib <- compile_cpp_lib(script = "scripts/square.cpp")
} # }
```
