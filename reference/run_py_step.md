# Execute a Python step (worker behind tar_target_py)

Runs, inside a fresh R environment, an optional R pre-script, a Python
script (via reticulate), and an optional R post-script, then returns
either a converted R object or a character vector of files. This is the
function the target built by
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md)
calls; it is exported so that call resolves at pipeline run time but
this function is not destined to be called directly by the package
users.

## Usage

``` r
run_py_step(
  script,
  pre_script = NULL,
  post_script = NULL,
  inputs = list(),
  output = "object",
  retrieve = NULL,
  files = NULL,
  python_version = NULL,
  env = NULL,
  env_manager = "system",
  python = NULL
)
```

## Arguments

- script:

  Path to the Python script to run (required).

- pre_script:

  Optional path to an R script run before the Python script. It is
  evaluated in the step environment, which already holds the named
  `inputs`. To hand objects to Python, assign a named list `to_py` in
  this script; each element is pushed as a top-level variable in the
  Python `__main__` module.

- post_script:

  Optional path to an R script run after the Python script. It is
  evaluated in the same environment, which now also holds `py` (the
  reticulate `__main__` module proxy) and `py_get(name)`. In
  `output = "object"` mode the value of its last expression becomes the
  target value; in `output = "file"` mode it must return a character
  vector of file paths.

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

- python_version:

  Optional Python version to select (e.g. `"3.12"` or `">=3.11"`), used
  only when no environment and no explicit `python` path are given.
  reticulate fetches/selects it (via its uv-backed ephemeral
  environment) with
  [`reticulate::py_require()`](https://rstudio.github.io/reticulate/reference/py_require.html).
  Default `NULL` uses the computer/global default Python. Use this when
  you only care about the interpreter *version* and are happy for
  reticulate to build a *throwaway* environment; for a *pinned,
  reproducible* environment use `env` / `env_manager` (or `python`)
  instead.

- env, env_manager, python:

  Python environment selection: the reproducible alternatives to
  `python_version`. Use `env` + `env_manager` to point at an existing
  environment built by a known tool, or `python` for one explicit
  interpreter path. `env_manager` is one of `"system"`, `"virtualenv"`,
  `"venv"`, `"conda"`, `"uv"`, `"poetry"`; `env` is the corresponding
  virtualenv/conda name or path (or poetry project directory); `python`
  is an explicit interpreter path. Precedence: `python` \> environment
  (`env`/`env_manager`) \> `python_version` \> default. (`"virtualenv"`,
  `"venv"` and `"uv"` all point at a standard virtualenv, including one
  created by `renv::use_python()`, and behave identically.) For
  `"virtualenv"`/`"venv"`/`"uv"`/`"poetry"`, an `env` that is an
  already-existing directory (relative to the working directory, or
  absolute) is resolved to an absolute path before use, so a relative
  venv path (e.g. `".venv"`, created with `uv venv .venv`) works as
  expected; otherwise
  [`reticulate::use_virtualenv()`](https://rstudio.github.io/reticulate/reference/use_python.html)
  would misread a separator-less relative path as the *name* of an
  environment under its own virtualenv root instead of a path on disk. A
  bare name that does not correspond to an existing directory is passed
  through unchanged, so a genuine named environment (one already
  registered under that root) still resolves. When `python` or an
  environment is given, the selection also takes priority over an
  ambient `RETICULATE_PYTHON` environment variable (e.g. one set by the
  RStudio project Python config and inherited by `crew` workers), which
  reticulate would otherwise let silently override the request.

## Value

The converted R object (object mode) or a character vector of normalised
file paths (file mode).

## See also

[`run_jl_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_jl_step.md),
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Normally invoked by tar_target_py(); shown here as a direct call.
# scripts/sum.py assigns `result`; pre.R builds `to_py <- list(x = x)`.
run_py_step(
  script = "scripts/sum.py",
  pre_script = "scripts/pre.R",
  inputs = list(x = c(1, 2, 3)),
  retrieve = "result"
)
} # }
```
