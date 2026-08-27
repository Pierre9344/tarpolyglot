# Changelog

## tarpolyglot 0.3.0

#### New features

- New
  [`toolchain_check()`](https://pierre9344.github.io/tarpolyglot/reference/toolchain_check.md)
  diagnostic function reports the status of the Python (via reticulate),
  Julia, and Rust toolchains: interpreter/compiler discovery in a fresh
  worker process, environment-manager presence (uv, Poetry, or conda for
  Python; juliaup and Julia’s `Pkg` project mechanism for Julia; rustup,
  cargo, and, on Windows, the GNU toolchain and Rtools for Rust), and
  multi-version discovery that lists every installed version per
  language and marks the one that would be used by default. Use
  `toolchains = c("py", "jl", "rs")` to check a subset, and
  `deep = FALSE` to skip the slower compile-reachability check for Rust.
- An RStudio addin (also working on Positron) exposes
  [`toolchain_check()`](https://pierre9344.github.io/tarpolyglot/reference/toolchain_check.md)
  (all languages, or Python/Julia/Rust individually) from the Addins
  menu.
- New
  [`tar_polyglot_log()`](https://pierre9344.github.io/tarpolyglot/reference/tar_polyglot_log.md),
  passed to `polyglot_controller(log = ...)`, turns on per-step
  stdout/stderr log files **for Python and Julia steps only**
  (`<step name>.out` / `<step name>.err`). Since `crew` launches worker
  processes before it knows which target they will run, the
  configuration is stashed as environment variables that every worker
  inherits, and
  [`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md)
  /
  [`run_jl_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_jl_step.md)
  do the actual redirection once they know the step name and resolved
  toolchain; `append` controls whether a re-run truncates or accumulates
  (with a two-blank-line separator) the log, and `header` prepends the
  step name, [`date()`](https://rdrr.io/r/base/date.html), interpreter
  version/path, and whether an explicit environment was used.
  **Deliberately does not cover
  [`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)**,
  for two independent reasons: `rextendr`-compiled code writes straight
  to the OS file descriptor, bypassing the redirection
  reticulate/JuliaCall provide for their embedded interpreters; and Rust
  steps don’t pay a per-branch interpreter start-up cost the way
  Python/Julia do in the first place, since a Rust library under
  `pattern` is already compiled once and reused across every branch
  ([`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md)
  and friends,
  [`compile_rs_lib()`](https://pierre9344.github.io/tarpolyglot/reference/compile_rs_lib.md)
  /
  [`run_rs_step_prebuilt()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step_prebuilt.md)),
  so there is correspondingly less need for a per-step Rust log. Use
  `crew`’s own `options_local(log_directory = ...)` for Rust step output
  instead (it also covers Python/Julia when `log` is left unset, since
  tarpolyglot never spawns a subprocess for them). Later extended to
  [`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md),
  see below.
- New
  [`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md)
  and
  [`tar_target_cpp_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp_raw.md)
  run C++ as `targets` steps via [Rcpp](https://www.rcpp.org/),
  mirroring
  [`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)
  closely: no live interpreter, `// [[Rcpp::export]]` functions in
  `script` are compiled with
  [`Rcpp::sourceCpp()`](https://rdrr.io/pkg/Rcpp/man/sourceCpp.html) and
  exposed to an R post-script, and
  [`run_cpp_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_cpp_step.md)
  puts R’s own `bin` directory, and on Windows Rtools, on `PATH` for the
  build. There is no separate toolchain or ABI to select the way Rust
  needs on Windows, `sourceCpp()` always compiles with whatever compiler
  R itself already uses, so
  [`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md)
  has no `toolchain` argument. A new `depends` argument
  (e.g. `depends = "RcppArmadillo"`) is a convenience alternative to a
  `// [[Rcpp::depends(pkgname)]]` source attribute for header only
  extension packages such as RcppArmadillo and RcppEigen, which
  otherwise need no tarpolyglot specific handling. A compiled function
  can also declare an `Rcpp::Function` parameter to call back into an
  ordinary R function, including one the caller supplies, with no extra
  plumbing needed. See
  [`vignette("cpp")`](https://pierre9344.github.io/tarpolyglot/articles/cpp.md).
- The `tarpolyglot_*()` pattern helpers
  ([`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md),
  [`tarpolyglot_cross()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_cross.md),
  [`tarpolyglot_slice()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_slice.md),
  [`tarpolyglot_head()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_head.md),
  [`tarpolyglot_tail()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_tail.md),
  [`tarpolyglot_sample()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_sample.md))
  now also compile once on
  [`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md),
  the same idea as for Rust but adapted to how
  [`Rcpp::sourceCpp()`](https://rdrr.io/pkg/Rcpp/man/sourceCpp.html)
  binds functions: since its generated wrappers capture a raw compiled
  routine pointer at bind time rather than resolving by name at call
  time the way rextendr’s do, the new
  [`compile_cpp_lib()`](https://pierre9344.github.io/tarpolyglot/reference/compile_cpp_lib.md)
  embeds the compiled library’s bytes together with its generated R
  wrapper source, and
  [`run_cpp_step_prebuilt()`](https://pierre9344.github.io/tarpolyglot/reference/run_cpp_step_prebuilt.md)
  re-evaluates that source in whichever process reloads the library,
  re-binding valid closures without recompiling. As with Rust,
  `sourceCpp()` names every freshly compiled library `sourceCpp_<N>`
  from a per-session counter, so
  [`run_cpp_step_prebuilt()`](https://pierre9344.github.io/tarpolyglot/reference/run_cpp_step_prebuilt.md)
  tracks the loaded library by content and hot-swaps when a different
  one needs the same module name, the same fix
  [`run_rs_step_prebuilt()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step_prebuilt.md)
  already has.
- [`toolchain_check()`](https://pierre9344.github.io/tarpolyglot/reference/toolchain_check.md)
  gained a `"cpp"` toolchain (now the default `toolchains` is
  `c("py", "jl", "rs", "cpp")`): a presence check for Rcpp itself only,
  not the extension packages (RcppArmadillo, RcppEigen, RcppParallel are
  the caller’s own choice via `depends`, not something tarpolyglot
  depends on); an OS appropriate compiler presence check (Rtools on
  Windows; on macOS and Linux, whichever compiler `R CMD config CXX`
  reports, queried rather than guessed so it is correct whether R was
  configured to use gcc or clang); and, when `deep = TRUE` (the
  default), compiling a trivial `// [[Rcpp::export]]` function in a
  fresh worker. The RStudio addin gained a matching C++ only entry.
- [`tar_polyglot_log()`](https://pierre9344.github.io/tarpolyglot/reference/tar_polyglot_log.md)
  now also covers
  [`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md).
  Unlike raw `std::cout` / `std::cerr` / `printf()`, which write
  straight to the OS file descriptor exactly like Rust’s `println!()`
  and are not captured, `Rcpp::Rcout` and `Rcpp::Rcerr` route through
  R’s own output connection system, so they are captured the same way
  [`cat()`](https://rdrr.io/r/base/cat.html) output is, confirmed
  empirically including from a fresh `crew` worker process.

#### Bug fixes

- Compiled Rust libraries no longer collide when several are used in one
  pipeline. rextendr names every compiled crate `rextendr<N>` from a
  per-process counter, so two libraries built in separate `crew` workers
  can both be `rextendr1`; a worker that later reused both would have
  resolved calls to whichever library loaded first.
  [`run_rs_step_prebuilt()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step_prebuilt.md)
  now tracks the loaded library by content and hot-swaps when a
  different one needs the same module name. As a result, pipelines with
  multiple
  [`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)
  steps (branching or not), reusing a compiled library across steps, and
  using more than one Rust library in a single step all behave
  correctly. See
  [`vignette("rust")`](https://pierre9344.github.io/tarpolyglot/articles/rust.md).
- The name argument of tar_target_py_raw() was documented as the
  worker’s logging argument (“Supplied automatically by the constructor;
  used only to name this step’s log files”), inherited by mistake from
  run_py_step(). It is now documented as the target name.

#### Documentation

- New
  [`vignette("scripts")`](https://pierre9344.github.io/tarpolyglot/articles/scripts.md)
  covers choosing between the three script forms and what each one means
  for change detection, mixing forms in a single call, the common
  mistake of giving
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  a file path instead of a target name, and why code assembled with
  `glue()` can use R objects that exist when `_targets.R` is sourced but
  cannot see the values of upstream targets.
- [`vignette("scripts")`](https://pierre9344.github.io/tarpolyglot/articles/scripts.md)
  also documents tracking helper files that a script imports, by
  pointing `inputs` at a `format = "file"` target, with matching
  examples on the Python and Julia constructors. Left untracked, editing
  a helper leaves the step up to date and returns a stale value. The
  pattern works for Python and Julia, where the helper is loaded at run
  time from the path bound in the step environment; Julia additionally
  needs that path made absolute, since `include()` resolves a relative
  path against the directory of the file doing the including rather than
  the working directory. It does not work for C++ and Rust, where
  [`run_cpp_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_cpp_step.md)
  and
  [`run_rs_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step.md)
  hand the script’s *text* to `Rcpp::sourceCpp(code = ...)` and
  `rextendr::rust_source(code = ...)`: the compiler then runs in a
  temporary build directory, so a neighbouring helper is not on its
  search path and a relative `#include "helper.h"` or
  `include!("helper.rs")` does not resolve. Listing the helper in
  `inputs` still registers it as a dependency there, so editing it
  re-runs and recompiles the step; only the loading half is unavailable.
- [`vignette("rust")`](https://pierre9344.github.io/tarpolyglot/articles/rust.md)
  now documents compiling a Rust library once and reusing it across
  unrelated steps
  ([`compile_rs_lib()`](https://pierre9344.github.io/tarpolyglot/reference/compile_rs_lib.md)
  /
  [`run_rs_step_prebuilt()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step_prebuilt.md)),
  defining several `#[extendr]` functions in one script, using more than
  one library in a step, and the accompanying limitations.
- [`vignette("rust")`](https://pierre9344.github.io/tarpolyglot/articles/rust.md)
  and the `tarpolyglot_*()` pattern helpers
  ([`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md),
  [`tarpolyglot_cross()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_cross.md),
  [`tarpolyglot_slice()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_slice.md),
  [`tarpolyglot_head()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_head.md),
  [`tarpolyglot_tail()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_tail.md),
  [`tarpolyglot_sample()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_sample.md))
  were modified to reflect the previously described limitations of these
  helpers on
  [`targets::tar_target()`](https://docs.ropensci.org/targets/reference/tar_target.html)
  and
  [`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html).
- [`vignette("python")`](https://pierre9344.github.io/tarpolyglot/articles/python.md),
  [`vignette("julia")`](https://pierre9344.github.io/tarpolyglot/articles/julia.md),
  and
  [`vignette("rust")`](https://pierre9344.github.io/tarpolyglot/articles/rust.md)
  were modified to improve their examples.
- New
  [`vignette("cpp")`](https://pierre9344.github.io/tarpolyglot/articles/cpp.md)
  covers the new C++ (Rcpp) workflow of tarpolyglot: when to use it over
  a plain
  [`tar_target()`](https://docs.ropensci.org/targets/reference/tar_target.html)
  calling
  [`Rcpp::sourceCpp()`](https://rdrr.io/pkg/Rcpp/man/sourceCpp.html)
  directly, extension packages, bringing an R function into C++ with
  `Rcpp::Function`, compile once branching, reusing a compiled library
  across steps, and
  [`tar_polyglot_log()`](https://pierre9344.github.io/tarpolyglot/reference/tar_polyglot_log.md)
  support.
- Parallel computing under `crew` workers documented for the first time,
  in
  [`vignette("cpp")`](https://pierre9344.github.io/tarpolyglot/articles/cpp.md),
  [`vignette("python")`](https://pierre9344.github.io/tarpolyglot/articles/python.md),
  [`vignette("julia")`](https://pierre9344.github.io/tarpolyglot/articles/julia.md),
  and a new item in
  [`vignette("get_started")`](https://pierre9344.github.io/tarpolyglot/articles/get_started.md)’s
  “Limitations to know first”: a `crew` worker has access to every core
  on the machine, not a restricted slice of it, so the real risk with a
  step that does internal parallel work (RcppParallel, Python
  `multiprocessing`, Julia `Distributed`) is several workers
  oversubscribing the machine by each spawning a full width thread or
  process pool at once, not lack of access to cores.
  `deployment = "main"` on the parallel-heavy step is the documented
  fix, since `targets` only ever builds one `main`-deployed target at a
  time. Demonstrated with a working `deployment = "main"` target in each
  of `examples/tarpolyglot_cpp`, `examples/tarpolyglot_py`, and
  `examples/tarpolyglot_jl`.
- All eight constructors
  ([`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md),
  [`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md),
  [`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md),
  [`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md),
  and their `_raw()` forms) now document the three ways to supply
  `script`, `pre_script`, and `post_script`, in a shared “Script
  options” section with identical wording everywhere: a literal path
  (untracked, so editing the file does not re-run the step), a
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference (tracked, so editing it does), or inline code from
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md)
  (hashed as part of the target’s command, so editing it does). Each of
  the eight gained `\dontrun{}` examples showing the three forms side by
  side.
- The step workers
  ([`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md),
  [`run_jl_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_jl_step.md),
  [`run_rs_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step.md),
  [`run_cpp_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_cpp_step.md),
  and the `compile_*_lib()` / `run_*_step_prebuilt()` helpers) gained a
  deliberately separate “Script arguments” section rather than repeating
  the constructors’ three forms, because a worker never sees three. By
  the time one runs, the constructor has already rewritten any
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference into the upstream target’s own file path, so a worker
  receives either a path on disk or an inline
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md)
  carrier; handing the result of
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  straight to a worker therefore does not resolve to a file.
- Examples no longer use , following the rOpenSci packaging guide.
  Building a target does not run it, so the examples for the eight
  constructors and for tar_code(), tar_target_path(),
  tar_polyglot_log(), polyglot_controller() and the tarpolyglot\_*()
  pattern helpers now execute during R CMD check on any machine, with no
  toolchain required. The nine topics that genuinely execute foreign
  code (run_py_step(), run_jl_step(), run_rs_step(), run_cpp_step(), the
  compile\_*\_lib() / run\_\*\_step_prebuilt() helpers, and
  toolchain_check()) are gated on Sys.getenv(“TARPOLYGLOT_EXAMPLES”) ==
  “true” and run inside targets::tar_dir(), mirroring how targets gates
  its own TAR_EXAMPLES examples. Continuous integration runs those gated
  examples, one R process per topic.
- Parameter documentation shared between constructors is now defined
  once and pulled in with
  [@inheritParams](https://github.com/inheritParams). Seven internal
  documentation targets were added for the arguments whose wording is
  common but whose meaning splits by form (\_raw() versus non-standard
  evaluation) or by language family (a live interpreter for Python and
  Julia, a compiled library for Rust and C++), removing eighteen
  duplicated [@param](https://github.com/param) descriptions with no
  change to the rendered help pages.
- New CONTRIBUTING.md describes how to report an issue or contribute to
  the package development.
- The hex logo was updated to reflect the addition of C++ support.
  `man/figures/logo.svg`, `man/figures/logo.png`, and every file in
  `pkgdown/favicon/` were regenerated to use this new logo. It was
  redraw to use original type-set marks (no third-party logo artwork).

#### Known limitations

- Contrary to what was announced in the “New features” section of the
  `0.2.0` version, the `tarpolyglot_*()` pattern helpers
  ([`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md),
  [`tarpolyglot_cross()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_cross.md),
  [`tarpolyglot_slice()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_slice.md),
  [`tarpolyglot_head()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_head.md),
  [`tarpolyglot_tail()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_tail.md),
  [`tarpolyglot_sample()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_sample.md))
  are recognised only inside the tarpolyglot constructors
  ([`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md),
  [`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md),
  [`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md),
  [`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md),
  and their `_raw()` forms). Used directly in a plain
  [`targets::tar_target()`](https://docs.ropensci.org/targets/reference/tar_target.html)
  or
  [`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html)
  they raise an
  `invalid dynamic branching pattern ... Illegal symbols found` error.
  This cannot be corrected from tarpolyglot: `targets` validates a
  pattern against a fixed set of pattern functions held in a locked
  internal environment, so recognising a new helper would require
  modifying the `targets` package itself. In a plain `targets` target
  (which has no foreign code to compile) use the native `map()` /
  `cross()` / `slice()` / [`head()`](https://rdrr.io/r/utils/head.html)
  / [`tail()`](https://rdrr.io/r/utils/head.html) /
  [`sample()`](https://rdrr.io/r/base/sample.html) instead.
- Julia’s native `Threads.@threads` multi-threading does not work
  through JuliaCall: `Threads.nthreads()` stays at `1` regardless of
  `JULIA_NUM_THREADS`, a limitation of how JuliaCall embeds Julia. Use
  `Distributed` (`addprocs()` + `pmap()`) instead, which works
  correctly; see
  [`vignette("julia")`](https://pierre9344.github.io/tarpolyglot/articles/julia.md),
  “Parallel computing (Distributed, not Threads)”.
- Every branch of one `pattern` shares a single
  [`tar_polyglot_log()`](https://pierre9344.github.io/tarpolyglot/reference/tar_polyglot_log.md)
  file, for any language: the log file name is fixed to the target’s own
  name before branching happens, and since `append = FALSE` truncates on
  every branch’s run, only the last branch to run leaves output in the
  file. Use `append = TRUE` to keep all branches’ output instead, or
  `crew`’s own `options_local(log_directory = ...)` for a genuinely one
  file per worker process log.

#### Notes

- Changes in this release respond to rOpenSci pre-submission feedback
  (ropensci/software-review#804).

## tarpolyglot 0.2.0

CRAN release: 2026-08-08

#### New features

- New dynamic-branching pattern helpers mirror the `targets` patterns
  (`map()`, `cross()`, `slice()`, …). Used unquoted in `pattern` on
  [`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)
  /
  [`tar_target_rs_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs_raw.md),
  they compile the Rust crate a single time in a companion
  `<step name>_rust_lib` target and reuse that compiled library across
  every branch (each branch reloads it in milliseconds), instead of
  recompiling the crate in every branch as the plain `targets` patterns
  do. On the other constructors
  ([`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md),
  [`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md),
  or
  [`tar_target()`](https://docs.ropensci.org/targets/reference/tar_target.html))
  each helper falls back to its plain `targets` equivalent, so the same
  pattern code branches every language.
  - [`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md):
    equivalent to `map()`
  - [`tarpolyglot_cross()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_cross.md):
    equivalent to `cross()`
  - [`tarpolyglot_slice()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_slice.md):
    equivalent to `slice()`
  - [`tarpolyglot_head()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_head.md):
    equivalent to [`head()`](https://rdrr.io/r/utils/head.html)
  - [`tarpolyglot_tail()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_tail.md):
    equivalent to [`tail()`](https://rdrr.io/r/utils/head.html)
  - [`tarpolyglot_sample()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_sample.md):
    equivalent to [`sample()`](https://rdrr.io/r/base/sample.html)

#### Bug fixes

- Inline Julia code supplied through
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md)
  now runs correctly when it spans multiple top-level statements (for
  example a `function` definition followed by a call). It is evaluated
  as a Julia script rather than as a single expression, so it no longer
  raises `ParseError("extra token after end of expression")`. Inline
  Python and Rust were unaffected.

## tarpolyglot 0.1.0

First release. `tarpolyglot` adds `targets` constructors that run
Python, Julia, and Rust as pipeline steps.

#### New features

- [`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md),
  [`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md),
  and
  [`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)
  (with matching `_raw()` variants) mirror
  [`targets::tar_target()`](https://docs.ropensci.org/targets/reference/tar_target.html)
  /
  [`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html).
  Python and Julia steps run a script through a live interpreter
  (reticulate / JuliaCall) with optional R pre- and post-scripts; Rust
  steps compile `#[extendr]` functions with rextendr and call them from
  an R post-script.
- Steps return either a converted R object or files written to disk
  (`output = "file"`).
- [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  tracks a script file as a real `targets` dependency, so a step re-runs
  when its script changes.
- [`polyglot_controller()`](https://pierre9344.github.io/tarpolyglot/reference/polyglot_controller.md)
  provides a `crew` controller preconfigured for per-step interpreter
  isolation (`tasks_max = 1`).
- Python environment selection via `env` / `env_manager` (system,
  virtualenv, venv, uv, poetry, conda), `python_version`, or an explicit
  `python` path; Julia selection via `julia_version` / `julia_home` /
  `julia_project` / `julia_packages`.
- Full
  [`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html)
  argument pass-through, including dynamic branching (`pattern`).
- [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md)
  supplies inline code for the `script`, `pre_script`, and `post_script`
  arguments of the constructors, as an alternative to a file path or a
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference. An R `{...}` block is captured as inline R and is valid in
  the `pre_script` / `post_script` slots; a character string is inline
  source for the foreign `script` (Python, Julia, or Rust) or for an R
  pre/post-script. Multi-line strings are dedented, so code indented to
  line up with `_targets.R` still starts flush-left and Python’s own
  block indentation stays valid. Inline code is embedded in the target’s
  command, so `targets` hashes it and re-runs the step when it changes.
