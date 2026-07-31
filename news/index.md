# Changelog

## tarpolyglot 0.2.0

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
