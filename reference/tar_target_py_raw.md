# Target that runs a Python script (raw / factory form)

Character-based constructor mirroring
[`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html):
`name` is a string and it is meant for use *inside targets factories*.
Returns a single `targets` target whose command runs an optional R
pre-script, `script` (via reticulate), and an optional R post-script,
then returns a converted R object or a character vector of files. See
[`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md)
for the pre/post-script contract (the `to_py` hand-off and the `py` /
`py_get` helpers). For direct use in `_targets.R`, see
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md).
The Julia twin is
[`tar_target_jl_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl_raw.md).

## Usage

``` r
tar_target_py_raw(
  name,
  script,
  pre_script = NULL,
  post_script = NULL,
  inputs = NULL,
  output = "object",
  retrieve = NULL,
  files = NULL,
  python_version = NULL,
  env = NULL,
  env_manager = "system",
  python = NULL,
  pattern = NULL,
  packages = targets::tar_option_get("packages"),
  library = targets::tar_option_get("library"),
  deps = NULL,
  string = NULL,
  format = NULL,
  repository = targets::tar_option_get("repository"),
  iteration = targets::tar_option_get("iteration"),
  error = targets::tar_option_get("error"),
  memory = targets::tar_option_get("memory"),
  garbage_collection = isTRUE(targets::tar_option_get("garbage_collection")),
  deployment = targets::tar_option_get("deployment"),
  priority = targets::tar_option_get("priority"),
  resources = targets::tar_option_get("resources"),
  storage = targets::tar_option_get("storage"),
  retrieval = targets::tar_option_get("retrieval"),
  cue = targets::tar_option_get("cue"),
  description = targets::tar_option_get("description")
)
```

## Arguments

- name:

  Character string, the target name.

- script:

  Path to the Python script to run (required). Either a literal string
  (an untracked path: editing the file does not invalidate the target)
  or a
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference to an upstream target (typically `format = "file"`), which
  makes this step re-run whenever that file changes.

- pre_script:

  Optional path to an R script run before the Python script. See
  [`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md);
  assign a named list `to_py` to hand objects to Python. Accepts a
  literal string or a
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference, as for `script`.

- post_script:

  Optional path to an R script run after the Python script. See
  [`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md);
  helpers `py` and `py_get()` are available, and its last expression
  (object mode) or returned paths (file mode) become the value. Accepts
  a literal string or a
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference, as for `script`.

- inputs:

  Named character vector (or list) mapping the name seen inside the step
  (in the R environment and, after the hand-off, in the foreign session)
  to the name of an upstream target, e.g. `c(x = "prepared_x")`. Each
  upstream target becomes a dependency of this target and is bound by
  that name in the step environment; under dynamic branching the
  per-branch slice is bound instead.

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

- pattern:

  Optional targets dynamic-branching pattern as a language object (e.g.
  `quote(map(x))`), forwarded to
  [`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html).

- packages, library:

  Character vectors of R packages (and library paths) to load for the
  target, forwarded to
  [`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html).

- deps, string:

  Advanced
  [`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html)
  arguments: extra dependency names and a string used for change
  detection.

- format, repository, iteration:

  Storage/iteration settings forwarded to
  [`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html).
  `format` defaults to `"file"` when `output = "file"`, otherwise to the
  `targets` option default.

- error, memory, garbage_collection, deployment, priority, resources,
  storage, retrieval, cue, description:

  Standard
  [`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html)
  execution/behaviour arguments, forwarded unchanged.

## Value

A `targets` target object.

## Details

All
[`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html)
arguments are forwarded unchanged, so dynamic branching (`pattern`),
storage `format`, `deployment`, `resources`, `cue`, etc. all work as
usual. Upstream targets are wired in through `inputs`, which become
dependencies (and are sliced under dynamic branching).

The interpreter/environment selection arguments (`python`, `env`,
`env_manager`, `python_version`) are forwarded to
[`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md),
which documents them (they are *alternatives*: normally set only one;
precedence `python` \> `env`/`env_manager` \> `python_version` \> none).
See also
[`vignette("python")`](https://pierre9344.github.io/tarpolyglot/articles/python.md)
for a decision guide with examples.

## See also

[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md),
[`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md),
[`tar_target_jl_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl_raw.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Inside a targets factory:
tarpolyglot::tar_target_py_raw(
  name = "py_sum",
  script = "scripts/sum.py",
  inputs = c(x = "prepared_x"),
  pre_script = "scripts/pre.R",   # builds `to_py <- list(x = x)`
  post_script = "scripts/post.R"  # ends on `py$result`
)
} # }
```
