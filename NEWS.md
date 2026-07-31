# tarpolyglot (development version)

### New features



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
