# tarpolyglot (development version)

### New features

* New `toolchain_check()` diagnostic function reports the status of the Python (via reticulate), Julia, and Rust toolchains: interpreter/compiler discovery in a fresh worker process, environment-manager presence (uv, Poetry, or conda for Python; juliaup and Julia's `Pkg` project mechanism for Julia; rustup, cargo, and, on Windows, the GNU toolchain and Rtools for Rust), and multi-version discovery that lists every installed version per language and marks the one that would be used by default. Use `toolchains = c("py", "jl", "rs")` to check a subset, and `deep = FALSE` to skip the slower compile-reachability check for Rust.
* An RStudio addin (also working on Positron) exposes `toolchain_check()` (all languages, or Python/Julia/Rust individually) from the Addins menu.
* New `tar_polyglot_log()`, passed to `polyglot_controller(log = ...)`, turns on per-step stdout/stderr log files **for Python and Julia steps only** (`<step name>.out` / `<step name>.err`). Since `crew` launches worker processes before it knows which target they will run, the configuration is stashed as environment variables that every worker inherits, and `run_py_step()` / `run_jl_step()` do the actual redirection once they know the step name and resolved toolchain; `append` controls whether a re-run truncates or accumulates (with a two-blank-line separator) the log, and `header` prepends the step name, `date()`, interpreter version/path, and whether an explicit environment was used. **Deliberately does not cover `tar_target_rs()`**, for two independent reasons: `rextendr`-compiled code writes straight to the OS file descriptor, bypassing the redirection reticulate/JuliaCall provide for their embedded interpreters; and Rust steps don't pay a per-branch interpreter start-up cost the way Python/Julia do in the first place, since a Rust library under `pattern` is already compiled once and reused across every branch (`tarpolyglot_map()` and friends, `compile_rs_lib()` / `run_rs_step_prebuilt()`), so there is correspondingly less need for a per-step Rust log. Use `crew`'s own `options_local(log_directory = ...)` for Rust step output instead (it also covers Python/Julia when `log` is left unset, since tarpolyglot never spawns a subprocess for them).

### Bug fixes

* Compiled Rust libraries no longer collide when several are used in one pipeline. rextendr names every compiled crate `rextendr<N>` from a per-process counter, so two libraries built in separate `crew` workers can both be `rextendr1`; a worker that later reused both would have resolved calls to whichever library loaded first. `run_rs_step_prebuilt()` now tracks the loaded library by content and hot-swaps when a different one needs the same module name. As a result, pipelines with multiple `tar_target_rs()` steps (branching or not), reusing a compiled library across steps, and using more than one Rust library in a single step all behave correctly. See `vignette("rust")`.

### Documentation

* `vignette("rust")` now documents compiling a Rust library once and reusing it across unrelated steps (`compile_rs_lib()` / `run_rs_step_prebuilt()`), defining several `#[extendr]` functions in one script, using more than one library in a step, and the accompanying limitations.
* `vignette("rust")` and the tarpolyglot_*()` pattern helpers (`tarpolyglot_map()`, `tarpolyglot_cross()`, `tarpolyglot_slice()`, `tarpolyglot_head()`, `tarpolyglot_tail()`, `tarpolyglot_sample()`) were modified to reflect the previously described limitions of these helpers on `targets::tar_target()` and targets::tar_target()_raw`

### Known limitations

* Contrary to what was annonced in the "New features" section of the `0.2.0` version, the tarpolyglot_*()` pattern helpers (`tarpolyglot_map()`, `tarpolyglot_cross()`, `tarpolyglot_slice()`, `tarpolyglot_head()`, `tarpolyglot_tail()`, `tarpolyglot_sample()`) are recognised only inside the tarpolyglot constructors (`tar_target_rs()`, `tar_target_py()`, `tar_target_jl()`, and their `_raw()` forms). Used directly in a plain `targets::tar_target()` or `targets::tar_target_raw()` they raise an `invalid dynamic branching pattern ... Illegal symbols found` error. This cannot be corrected from tarpolyglot: `targets` validates a pattern against a fixed set of pattern functions held in a locked internal environment, so recognising a new helper would require modifying the `targets` package itself. In a plain `targets` target (which has no foreign code to compile) use the native `map()` / `cross()` / `slice()` / `head()` / `tail()` / `sample()` instead.

# tarpolyglot 0.2.0

### New features

* New dynamic-branching pattern helpers mirror the `targets` patterns (`map()`, `cross()`, `slice()`, ...). Used unquoted in `pattern` on `tar_target_rs()` / `tar_target_rs_raw()`, they compile the Rust crate a single time in a companion `<step name>_rust_lib` target and reuse that compiled library across every branch (each branch reloads it in milliseconds), instead of recompiling the crate in every branch as the plain `targets` patterns do. On the other constructors (`tar_target_py()`, `tar_target_jl()`, or `tar_target()`) each helper falls back to its plain `targets` equivalent, so the same pattern code branches every language.
  * `tarpolyglot_map()`: equivalent to `map()`
  * `tarpolyglot_cross()`: equivalent to `cross()`
  * `tarpolyglot_slice()`: equivalent to `slice()`
  * `tarpolyglot_head()`: equivalent to `head()`
  * `tarpolyglot_tail()`: equivalent to `tail()`
  * `tarpolyglot_sample()`: equivalent to `sample()`

### Bug fixes

* Inline Julia code supplied through `tar_code()` now runs correctly when it spans multiple top-level statements (for example a `function` definition followed by a call). It is evaluated as a Julia script rather than as a single expression, so it no longer raises `ParseError("extra token after end of expression")`. Inline Python and Rust were unaffected.

# tarpolyglot 0.1.0

First release. `tarpolyglot` adds `targets` constructors that run Python, Julia, and Rust as pipeline steps.

### New features

* `tar_target_py()`, `tar_target_jl()`, and `tar_target_rs()` (with matching `_raw()` variants) mirror `targets::tar_target()` / `targets::tar_target_raw()`. Python and Julia steps run a script through a live interpreter (reticulate / JuliaCall) with optional R pre- and post-scripts; Rust steps compile `#[extendr]` functions with rextendr and call them from an R post-script.
* Steps return either a converted R object or files written to disk (`output = "file"`).
* `tar_target_path()` tracks a script file as a real `targets` dependency, so a step re-runs when its script changes.
* `polyglot_controller()` provides a `crew` controller preconfigured for per-step interpreter isolation (`tasks_max = 1`).
* Python environment selection via `env` / `env_manager` (system, virtualenv, venv, uv, poetry, conda), `python_version`, or an explicit `python` path; Julia selection via `julia_version` / `julia_home` / `julia_project` / `julia_packages`.
* Full `targets::tar_target_raw()` argument pass-through, including dynamic branching (`pattern`).
* `tar_code()` supplies inline code for the `script`, `pre_script`, and `post_script` arguments of the constructors, as an alternative to a file path or a `tar_target_path()` reference. An R `{...}` block is captured as inline R and is valid in the `pre_script` / `post_script` slots; a character string is inline source for the foreign `script` (Python, Julia, or Rust) or for an R pre/post-script. Multi-line strings are dedented, so code indented to line up with `_targets.R` still starts flush-left and Python's own block indentation stays valid. Inline code is embedded in the target's command, so `targets` hashes it and re-runs the step when it changes.
