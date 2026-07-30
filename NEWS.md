# tarpolyglot 0.1.0

First release. `tarpolyglot` adds `targets` constructors that run Python, Julia, and Rust as pipeline steps.

* `tar_target_py()` / `tar_target_jl()` / `tar_target_rs()` (and matching `_raw()` variants) mirror `targets::tar_target()` / `targets::tar_target_raw()`. Python and Julia steps run a script via a live interpreter (reticulate / JuliaCall) with optional R pre- and post-scripts; Rust steps compile `#[extendr]` functions with rextendr and call them from an R post-script.
* Results are returned as converted R objects or as files written to disk (`output = "file"`).
* `tar_target_path()` tracks a script file as a real `targets` dependency, so a step re-runs when its script changes.
* `polyglot_controller()` provides a `crew` controller preconfigured for per-step interpreter isolation (`tasks_max = 1`).
* Python environment selection via `env` / `env_manager` (system, virtualenv, venv, uv, poetry, conda), `python_version`, or an explicit `python` path; Julia selection via `julia_version` / `julia_home` / `julia_project` / `julia_packages`.
* Full `targets::tar_target_raw()` argument pass-through, including dynamic branching (`pattern`).
