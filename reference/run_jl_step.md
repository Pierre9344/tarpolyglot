# Execute a Julia step (worker behind tar_target_jl)

Julia counterpart of
[`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md).
Runs, inside a fresh R environment, an optional R pre-script, a Python
script (via JuliaCall). This is the function the target built by
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md)
calls; it is exported so that call resolves at pipeline run time but
this function is not destined to be called directly by the package
users.

## Usage

``` r
run_jl_step(
  script,
  pre_script = NULL,
  post_script = NULL,
  inputs = list(),
  output = "object",
  retrieve = NULL,
  files = NULL,
  julia_version = NULL,
  julia_home = getOption("tarpolyglot.julia_home"),
  julia_project = NULL,
  julia_packages = NULL,
  name = NULL
)
```

## Arguments

- script:

  Path to the Julia script to run (required). Accepts a file path or an
  inline
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md)
  carrier; see the "Script arguments" section below.

- pre_script:

  Optional path to an R script run before the Julia script. It is
  evaluated in the step environment, which already holds the named
  `inputs`. To hand objects to Julia, assign a named list `to_jl` in
  this script; each element is `julia_assign()`ed as a variable in
  Julia's `Main` module. Accepts a file path or an inline
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md)
  carrier; see the "Script arguments" section below.

- post_script:

  Optional path to an R script run after the Julia script. It is
  evaluated in the same environment, which now also holds `jl_get(name)`
  and `jl_call(fn, ...)`. In `output = "object"` mode the value of its
  last expression becomes the target value; in `output = "file"` mode it
  must return a character vector of file paths. Accepts a file path or
  an inline
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md)
  carrier; see the "Script arguments" section below.

- inputs:

  Named list of upstream target values, bound by name into the step
  environment. Supplied automatically by the constructor.

- output:

  Output mode: `"object"` (default) returns a converted R object,
  `"file"` returns a character vector of file paths (and defaults
  `format` to `"file"`).

- retrieve:

  Optional character vector of foreign-session variable names to return
  when no `post_script` is supplied in object mode. One name returns
  that object; several return a named list.

- files:

  Optional character vector of file paths to return when no
  `post_script` is supplied in file mode.

- julia_version:

  Optional Julia version to select (e.g. `"1.11"`), used when
  `julia_home` is not given. Resolved to a
  [juliaup](https://github.com/JuliaLang/juliaup)-managed install.
  Default `NULL` uses the computer/global default Julia.

- julia_home, julia_project, julia_packages:

  Julia environment selection. `julia_home` is the directory containing
  the julia executable (defaults to
  `getOption("tarpolyglot.julia_home")`; when unset and no
  `julia_version`, JuliaCall discovers Julia on `PATH`). `julia_project`
  is a Julia project environment (folder with `Project.toml` /
  `Manifest.toml`) to `Pkg.activate()`; when `NULL`, Julia's default
  global environment (`@v#.#`) is used. `julia_packages` is a character
  vector of packages to `using` before the script. The requested
  environment takes priority over an ambient `JULIA_PROJECT` environment
  variable (e.g. one set by an RStudio project config and inherited by
  `crew` workers): it is cleared for the duration of the Julia binding,
  so an explicit `julia_project` (or the global environment you get when
  none is given) wins over it, rather than `JULIA_PROJECT` silently
  selecting a different project. (`JULIA_HOME` is not cleared: it is a
  supported way to point at the default Julia.)

- name:

  Character string, the step's target name. Supplied automatically by
  the constructor; used only to name this step's log files when
  [`polyglot_controller()`](https://pierre9344.github.io/tarpolyglot/reference/polyglot_controller.md)
  was given a
  [`tar_polyglot_log()`](https://pierre9344.github.io/tarpolyglot/reference/tar_polyglot_log.md)
  (`NULL` – the default – disables logging for a direct call).

## Value

The converted R object (object mode) or a character vector of normalised
file paths (file mode).

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

[`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md),
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Normally invoked by tar_target_jl(); shown here as a direct call.
# scripts/pre.R:
#   to_jl <- list(x = x)
# scripts/sum.jl:
#   result = sum(x)
run_jl_step(
  script = "scripts/sum.jl",
  pre_script = "scripts/pre.R",
  inputs = list(x = c(1, 2, 3)),
  retrieve = "result"
)
} # }
```
