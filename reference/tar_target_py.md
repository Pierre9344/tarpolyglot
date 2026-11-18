# Target that runs a Python script

Non-standard-evaluation constructor mirroring
[`targets::tar_target()`](https://docs.ropensci.org/targets/reference/tar_target.html):
pass a bare `name` and an unquoted `pattern`, for direct use in
`_targets.R`. It quotes those and delegates to
[`tar_target_py_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py_raw.md).
See that function and
[`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md)
for the full argument reference and the pre/post-script contract. The
Julia twin is
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md).

## Usage

``` r
tar_target_py(
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

  Symbol, the target name (unquoted).

- script:

  Path to the Python script to run (required). Accepts a literal path, a
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference, or inline code from
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md);
  see the "Script options" section below.

- pre_script:

  Optional path to an R script run before the Python script. See
  [`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md);
  assign a named list `to_py` to hand objects to Python. Accepts a
  literal path, a
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference, or inline code from
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md);
  see the "Script options" section below.

- post_script:

  Optional path to an R script run after the Python script. See
  [`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md);
  helpers `py` and `py_get()` are available, and its last expression
  (object mode) or returned paths (file mode) become the value. Accepts
  a literal path, a
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference, or inline code from
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md);
  see the "Script options" section below.

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

  Optional dynamic-branching pattern, unquoted (e.g. `map(x)`).

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

## Script options

Every script argument (`script`, and `pre_script` / `post_script` where
the constructor has them) accepts the same three forms. The choice is
not cosmetic: it decides whether editing the code re-runs the target.

- A literal path string:

  e.g. `script = "py/step.py"`. The file is read when the step runs, but
  it is **not** tracked, so editing it does **not** invalidate the
  target: `targets` will happily reuse a stale result until some *other*
  dependency changes. Simplest form, and a reasonable default once a
  script has settled.

- A
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference:

  e.g. `script = tar_target_path("step_py")`, naming an upstream
  `tar_target(step_py, "py/step.py", format = "file")`. The file becomes
  a real `targets` dependency, so editing it **does** invalidate this
  target and the step re-runs. This is what you want while a script is
  still changing, and the recommended form for reproducible pipelines.

- Inline code via
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md):

  e.g. `script = tar_code("result = sum(x)")`. The code lives in
  `_targets.R` rather than in a file, and is embedded in the target's
  command, so `targets` hashes it and editing it **does** invalidate the
  target. A character string carries foreign source (Python, Julia,
  Rust, C++) or R source; an R `{ ... }` block carries inline R and is
  accepted only by `pre_script` / `post_script`, never by the foreign
  `script`.

Mixing forms in one call is fine: a tracked `script` with a literal
`post_script`, inline code for one and a file for another, and so on.
See
[`vignette("scripts")`](https://pierre9344.github.io/tarpolyglot/articles/scripts.md)
for worked examples of all three and guidance on choosing.

## See also

[`tar_target_py_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py_raw.md),
[`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md),
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md)

## Examples

``` r
# Building a target does not run it, so these examples need no Python.
# Inside _targets.R:
# scripts/sum.py:
#   result = sum(x)
# scripts/post.R:
#   py$result
list(
  tarpolyglot::tar_target_py(
    name = py_sum,
    script = "scripts/sum.py",
    inputs = c(x = "prepared_x"),
    post_script = "scripts/post.R"
  )
)
#> [[1]]
#> <tar_stem> 
#>   name: py_sum 
#>   description:  
#>   command:
#>     tarpolyglot::run_py_step(script = "scripts/sum.py", 
#>         pre_script = NULL, post_script = "scripts/post.R", inputs = list(x = prepared_x), 
#>         output = "object", retrieve = NULL, files = NULL, python_version = NULL, 
#>         env = NULL, env_manager = "system", python = NULL, name = "py_sum") 
#>   format: rds 
#>   repository: local 
#>   iteration method: vector 
#>   error mode: stop 
#>   memory mode: auto 
#>   storage mode: worker 
#>   retrieval mode: auto 
#>   deployment mode: worker 
#>   priority: 0 
#>   resources:
#>     list() 
#>   cue:
#>     seed: TRUE
#>     file: TRUE
#>     iteration: TRUE
#>     repository: TRUE
#>     format: TRUE
#>     depend: TRUE
#>     command: TRUE
#>     mode: thorough 
#>   packages:
#>     tarpolyglot
#>     stats
#>     graphics
#>     grDevices
#>     utils
#>     datasets
#>     methods
#>     base 
#>   library:
#>     NULL

# The three ways to supply a script (see the "Script options" section):
# 1. Literal path: untracked, editing the file does NOT re-run the step.
tarpolyglot::tar_target_py(
  name = demo_literal, script = "py/step.py", retrieve = "result"
)
#> <tar_stem> 
#>   name: demo_literal 
#>   description:  
#>   command:
#>     tarpolyglot::run_py_step(script = "py/step.py", pre_script = NULL, 
#>         post_script = NULL, inputs = list(), output = "object", retrieve = "result", 
#>         files = NULL, python_version = NULL, env = NULL, env_manager = "system", 
#>         python = NULL, name = "demo_literal") 
#>   format: rds 
#>   repository: local 
#>   iteration method: vector 
#>   error mode: stop 
#>   memory mode: auto 
#>   storage mode: worker 
#>   retrieval mode: auto 
#>   deployment mode: worker 
#>   priority: 0 
#>   resources:
#>     list() 
#>   cue:
#>     seed: TRUE
#>     file: TRUE
#>     iteration: TRUE
#>     repository: TRUE
#>     format: TRUE
#>     depend: TRUE
#>     command: TRUE
#>     mode: thorough 
#>   packages:
#>     tarpolyglot
#>     stats
#>     graphics
#>     grDevices
#>     utils
#>     datasets
#>     methods
#>     base 
#>   library:
#>     NULL

# 2. tar_target_path(): tracked, editing the file DOES re-run the step.
list(
  targets::tar_target(step_py, "py/step.py", format = "file"),
  tarpolyglot::tar_target_py(
    name = demo_tracked,
    script = tarpolyglot::tar_target_path("step_py"),
    retrieve = "result"
  )
)
#> [[1]]
#> <tar_stem> 
#>   name: step_py 
#>   description:  
#>   command:
#>     "py/step.py" 
#>   format: file 
#>   repository: local 
#>   iteration method: vector 
#>   error mode: stop 
#>   memory mode: auto 
#>   storage mode: worker 
#>   retrieval mode: auto 
#>   deployment mode: worker 
#>   priority: 0 
#>   resources:
#>     list() 
#>   cue:
#>     seed: TRUE
#>     file: TRUE
#>     iteration: TRUE
#>     repository: TRUE
#>     format: TRUE
#>     depend: TRUE
#>     command: TRUE
#>     mode: thorough 
#>   packages:
#>     tarpolyglot
#>     stats
#>     graphics
#>     grDevices
#>     utils
#>     datasets
#>     methods
#>     base 
#>   library:
#>     NULL
#> [[2]]
#> <tar_stem> 
#>   name: demo_tracked 
#>   description:  
#>   command:
#>     tarpolyglot::run_py_step(script = step_py, pre_script = NULL, 
#>         post_script = NULL, inputs = list(), output = "object", retrieve = "result", 
#>         files = NULL, python_version = NULL, env = NULL, env_manager = "system", 
#>         python = NULL, name = "demo_tracked") 
#>   format: rds 
#>   repository: local 
#>   iteration method: vector 
#>   error mode: stop 
#>   memory mode: auto 
#>   storage mode: worker 
#>   retrieval mode: auto 
#>   deployment mode: worker 
#>   priority: 0 
#>   resources:
#>     list() 
#>   cue:
#>     seed: TRUE
#>     file: TRUE
#>     iteration: TRUE
#>     repository: TRUE
#>     format: TRUE
#>     depend: TRUE
#>     command: TRUE
#>     mode: thorough 
#>   packages:
#>     tarpolyglot
#>     stats
#>     graphics
#>     grDevices
#>     utils
#>     datasets
#>     methods
#>     base 
#>   library:
#>     NULL

# 3. tar_code(): inline, editing the code DOES re-run the step. A string
#    carries foreign source; an R { } block carries inline R.
tarpolyglot::tar_target_py(
  name = demo_inline,
  script = tarpolyglot::tar_code("result = 1 + 1"),
  post_script = tarpolyglot::tar_code({ py_get("result") })
)
#> <tar_stem> 
#>   name: demo_inline 
#>   description:  
#>   command:
#>     tarpolyglot::run_py_step(script = structure(list(code = "result = 1 + 1"), 
#>         class = c("tp_inline", "tp_source")), pre_script = NULL, 
#>         post_script = structure(list(code = quote({
#>             py_get("result")
#>         })), class = c("tp_inline", "tp_expr")), inputs = list(), 
#>         output = "object", retrieve = NULL, files = NULL, python_version = NULL, 
#>         env = NULL, env_manager = "system", python = NULL, name = "demo_inline") 
#>   format: rds 
#>   repository: local 
#>   iteration method: vector 
#>   error mode: stop 
#>   memory mode: auto 
#>   storage mode: worker 
#>   retrieval mode: auto 
#>   deployment mode: worker 
#>   priority: 0 
#>   resources:
#>     list() 
#>   cue:
#>     seed: TRUE
#>     file: TRUE
#>     iteration: TRUE
#>     repository: TRUE
#>     format: TRUE
#>     depend: TRUE
#>     command: TRUE
#>     mode: thorough 
#>   packages:
#>     tarpolyglot
#>     stats
#>     graphics
#>     grDevices
#>     utils
#>     datasets
#>     methods
#>     base 
#>   library:
#>     NULL

# Tracking a helper module the script imports. Point `inputs` at a
# format = "file" target so editing the helper also re-runs the step;
# `inputs` takes the *target* name, not the path. py/step.py then loads
# the helper from the bound path rather than a hard-coded one:
#   import os, sys
#   sys.path.insert(0, os.path.dirname(helper_path))
#   import helper
#   result = sum(helper.scale(x))
list(
  targets::tar_target(helper_file, "py/helper.py", format = "file"),
  tarpolyglot::tar_target_py(
    name = demo_helper,
    script = "py/step.py",
    inputs = c(x = "prepared_x", helper_path = "helper_file"),
    pre_script = tarpolyglot::tar_code({
      to_py <- list(x = x, helper_path = helper_path)
    }),
    retrieve = "result"
  )
)
#> [[1]]
#> <tar_stem> 
#>   name: helper_file 
#>   description:  
#>   command:
#>     "py/helper.py" 
#>   format: file 
#>   repository: local 
#>   iteration method: vector 
#>   error mode: stop 
#>   memory mode: auto 
#>   storage mode: worker 
#>   retrieval mode: auto 
#>   deployment mode: worker 
#>   priority: 0 
#>   resources:
#>     list() 
#>   cue:
#>     seed: TRUE
#>     file: TRUE
#>     iteration: TRUE
#>     repository: TRUE
#>     format: TRUE
#>     depend: TRUE
#>     command: TRUE
#>     mode: thorough 
#>   packages:
#>     tarpolyglot
#>     stats
#>     graphics
#>     grDevices
#>     utils
#>     datasets
#>     methods
#>     base 
#>   library:
#>     NULL
#> [[2]]
#> <tar_stem> 
#>   name: demo_helper 
#>   description:  
#>   command:
#>     tarpolyglot::run_py_step(script = "py/step.py", pre_script = structure(list(code = quote({
#>         to_py <- list(x = x, helper_path = helper_path)
#>     })), class = c("tp_inline", "tp_expr")), post_script = NULL, 
#>         inputs = list(x = prepared_x, helper_path = helper_file), 
#>         output = "object", retrieve = "result", files = NULL, python_version = NULL, 
#>         env = NULL, env_manager = "system", python = NULL, name = "demo_helper") 
#>   format: rds 
#>   repository: local 
#>   iteration method: vector 
#>   error mode: stop 
#>   memory mode: auto 
#>   storage mode: worker 
#>   retrieval mode: auto 
#>   deployment mode: worker 
#>   priority: 0 
#>   resources:
#>     list() 
#>   cue:
#>     seed: TRUE
#>     file: TRUE
#>     iteration: TRUE
#>     repository: TRUE
#>     format: TRUE
#>     depend: TRUE
#>     command: TRUE
#>     mode: thorough 
#>   packages:
#>     tarpolyglot
#>     stats
#>     graphics
#>     grDevices
#>     utils
#>     datasets
#>     methods
#>     base 
#>   library:
#>     NULL
```
