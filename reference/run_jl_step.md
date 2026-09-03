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
  julia_packages = NULL
)
```

## Arguments

- script:

  Path to the Julia script to run (required).

- pre_script:

  Optional path to an R script run before the Julia script. It is
  evaluated in the step environment, which already holds the named
  `inputs`. To hand objects to Julia, assign a named list `to_jl` in
  this script; each element is `julia_assign()`ed as a variable in
  Julia's `Main` module.

- post_script:

  Optional path to an R script run after the Julia script. It is
  evaluated in the same environment, which now also holds `jl_get(name)`
  and `jl_call(fn, ...)`. In `output = "object"` mode the value of its
  last expression becomes the target value; in `output = "file"` mode it
  must return a character vector of file paths.

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

## Value

The converted R object (object mode) or a character vector of normalised
file paths (file mode).

## See also

[`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md),
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Normally invoked by tar_target_jl(); shown here as a direct call.
# scripts/sum.jl assigns `result`; pre.R builds `to_jl <- list(x = x)`.
run_jl_step(
  script = "scripts/sum.jl",
  pre_script = "scripts/pre.R",
  inputs = list(x = c(1, 2, 3)),
  retrieve = "result"
)
} # }
```
