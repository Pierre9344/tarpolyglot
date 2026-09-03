# Package index

## Package overview

- [`tarpolyglot`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot-package.md)
  [`tarpolyglot-package`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot-package.md)
  : tarpolyglot: run Python, Julia, and Rust as targets pipeline steps

## Target constructors

Build a targets step that runs Python, Julia, or Rust. The non-`_raw`
forms use non-standard evaluation on `name`/`pattern` for direct use in
`_targets.R`; the `_raw` forms take a string `name` for use inside
targets factories.

- [`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md)
  : Target that runs a Python script
- [`tar_target_py_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py_raw.md)
  : Target that runs a Python script (raw / factory form)
- [`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md)
  : Target that runs a Julia script
- [`tar_target_jl_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl_raw.md)
  : Target that runs a Julia script (raw / factory form)
- [`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)
  : Target that runs a Rust script
- [`tar_target_rs_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs_raw.md)
  : Target that runs a Rust script (raw / factory form)

## Helpers

Supply a step’s code inline, track a script file as a dependency, branch
while compiling Rust once, and a crew controller preconfigured for
per-step interpreter isolation.

- [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md)
  : Inline code for a tarpolyglot step

- [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  :

  Track a script argument as a `targets` dependency

- [`polyglot_controller()`](https://pierre9344.github.io/tarpolyglot/reference/polyglot_controller.md)
  : A crew controller preconfigured for polyglot isolation

## Branching patterns

Dynamic-branching pattern helpers that mirror the `targets` patterns but
compile the Rust crate once per pattern (in a `<name>_rust_lib` target)
and reuse it across branches. On the Python/Julia constructors they fall
back to the plain `targets` pattern.

- [`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md)
  : Dynamic-branching map that compiles Rust once
- [`tarpolyglot_cross()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_cross.md)
  : Dynamic-branching cross that compiles Rust once
- [`tarpolyglot_slice()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_slice.md)
  : Dynamic-branching slice that compiles Rust once
- [`tarpolyglot_head()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_head.md)
  : Dynamic-branching head that compiles Rust once
- [`tarpolyglot_tail()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_tail.md)
  : Dynamic-branching tail that compiles Rust once
- [`tarpolyglot_sample()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_sample.md)
  : Dynamic-branching sample that compiles Rust once

## Step workers

Worker functions the constructors call at pipeline run time. Documented
because the constructor pages link to them; you do not normally call
them directly.

- [`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md)
  : Execute a Python step (worker behind tar_target_py)
- [`run_jl_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_jl_step.md)
  : Execute a Julia step (worker behind tar_target_jl)
- [`run_rs_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step.md)
  : Execute a Rust step (worker behind tar_target_rs)
- [`compile_rs_lib()`](https://pierre9344.github.io/tarpolyglot/reference/compile_rs_lib.md)
  : Compile a Rust step once for reuse across branches (worker behind
  tarpolyglot_map)
- [`run_rs_step_prebuilt()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step_prebuilt.md)
  : Run a Rust step from a pre-compiled library (worker behind
  tarpolyglot_map)
