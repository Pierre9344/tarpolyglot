# Diagnose the Python, Julia, Rust, and C++ toolchains

Runs a battery of checks for whichever toolchains you ask for and
reports the result with [cli](https://cli.r-lib.org/) as it goes:
interpreter/compiler discovery, environment-manager availability, and,
most importantly, whether each toolchain is actually *reachable from a
fresh worker process* – the same kind of process `crew` spawns to run a
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md)/[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md)/[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)
step. This is meant to preempt the common "it doesn't run on my machine"
class of issue before you find out the hard way, mid-pipeline.

## Usage

``` r
toolchain_check(
  toolchains = c("py", "jl", "rs", "cpp"),
  deep = TRUE,
  quiet = FALSE
)
```

## Arguments

- toolchains:

  Character vector, which toolchains to check: any subset of `"py"`,
  `"jl"`, `"rs"`, `"cpp"`. Default checks all four.

- deep:

  Logical. When `TRUE` (the default), the Rust and C++ checks
  additionally compile a trivial function (`#[extendr]` /
  `// [[Rcpp::export]]`) in a fresh worker to prove the full toolchain
  actually links together end to end; this is the most informative check
  for each but also the slowest (well under a minute, but not instant).
  Set `deep = FALSE` to skip it and rely on the faster presence checks
  alone. Python and Julia's fresh-worker checks are cheap either way and
  always run.

- quiet:

  Logical, default `FALSE`. Suppress the live `cli` progress/result
  output; the return value is unaffected either way.

## Value

Invisibly, a `data.frame` with one row per check and columns `toolchain`
(`"py"`/`"jl"`/`"rs"`/`"cpp"`), `check` (a short label), `status`
(`"ok"`, `"warn"`, or `"fail"`), and `detail` (a human-readable
description, e.g. the resolved path and version, or an error message).

## Details

Environment managers checked per language: for Python, `uv`, `poetry`,
and `conda` (three separate, competing tools, plus the stdlib `venv`
module on the resolved interpreter). For Julia, `juliaup` (which manages
*versions*, checked via presence + the list of installed versions) and,
separately, Julia's own `Pkg` project-environment mechanism (which
manages *packages*, activated with `Pkg.activate()` – the actual
mechanism behind `julia_project`/`julia_packages`): a fresh worker
actually activates a throwaway project to prove it works, not just that
Julia is present. Rust has no separate environment concept (see
[`vignette("rust")`](https://pierre9344.github.io/tarpolyglot/articles/rust.md));
`rustup`/`cargo`/(on Windows) the GNU toolchain and Rtools are checked
instead.

Every check that would bind an interpreter (Python, Julia) or compile
code (Rust, C++) runs inside a disposable
[`callr::r()`](https://callr.r-lib.org/reference/r.html) subprocess,
never in your current R session: this means `toolchain_check()` cannot
leave reticulate or JuliaCall bound afterwards, and it is answering the
*real* question ("would a crew worker be able to do this right now"),
not just "is something already loaded in this session". Plain presence
checks ([`Sys.which()`](https://rdrr.io/r/base/Sys.which.html) for `uv`,
`poetry`, `rustup`, and so on, or
[`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) for Rcpp)
run directly, since they have no side effects to isolate.

When more than one version is found, each language also reports every
installed version it can enumerate, with its path and which one is the
default (the one a step would actually use if you set nothing): Python
via `uv python list --only-installed` (matched against the resolved
interpreter primarily by exact version, since reticulate's default is
often an *ephemeral* uv-provisioned interpreter that lives under uv's
cache rather than its "installed" registry, so the two rarely share a
literal path even when they are, in fact, the same build); Julia via the
juliaup depot; Rust via `rustup toolchain list -v` (which marks its own
default inline, no cross-referencing needed). With only one version
found, this is a single summary line instead. C++ has no separate
version-manager concept to enumerate this way (see
[`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md)):
it compiles via R's own configured toolchain, so its checks are presence
(Rcpp; the OS-appropriate compiler, Rtools on Windows or the actual
`R CMD config CXX` compiler command on macOS/Linux, queried rather than
guessed so it is correct under gcc or clang alike) plus, with
`deep = TRUE`, a compile-reachability check. Extension packages such as
RcppArmadillo/RcppEigen/RcppParallel are not checked here since
tarpolyglot itself does not depend on any of them; they are entirely the
caller's own choice via `depends` (see
[`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md)).

## See also

[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md),
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md),
[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md),
[`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md)

## Examples

``` r
if (FALSE) { # \dontrun{
toolchain_check()                      # everything
toolchain_check("py")                  # Python only
toolchain_check(c("jl", "rs"))         # Julia and Rust
toolchain_check("rs", deep = FALSE)    # skip the Rust compile test
toolchain_check("cpp")                 # C++ only
res <- toolchain_check(quiet = TRUE)   # no console output, just the data.frame
res[res$status != "ok", ]              # anything that needs attention
} # }
```
