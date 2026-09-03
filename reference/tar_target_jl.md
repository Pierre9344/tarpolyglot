# Target that runs a Julia script

Non-standard-evaluation constructor mirroring
[`targets::tar_target()`](https://docs.ropensci.org/targets/reference/tar_target.html):
pass a bare `name` and unquoted `pattern`, for direct use in
`_targets.R`. Delegates to
[`tar_target_jl_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl_raw.md);
see it and
[`run_jl_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_jl_step.md)
for the full reference. The Python twin is
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md).

## Usage

``` r
tar_target_jl(
  name,
  script,
  pre_script = NULL,
  post_script = NULL,
  inputs = NULL,
  output = "object",
  retrieve = NULL,
  files = NULL,
  julia_version = NULL,
  julia_home = getOption("tarpolyglot.julia_home"),
  julia_project = NULL,
  julia_packages = NULL,
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

  Path to the Julia script to run (required). Either a literal string
  (an untracked path: editing the file does not invalidate the target)
  or a
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference to an upstream target (typically `format = "file"`), which
  makes this step re-run whenever that file changes.

- pre_script:

  Optional path to an R script run before the Julia script. See
  [`run_jl_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_jl_step.md);
  assign a named list `to_jl` to hand objects to Julia. Accepts a
  literal string or a
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference, as for `script`.

- post_script:

  Optional path to an R script run after the Julia script. See
  [`run_jl_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_jl_step.md);
  helpers `jl_get()` and `jl_call()` are available, and its last
  expression (object mode) or returned paths (file mode) become the
  value. Accepts a literal string or a
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

- julia_version:

  Optional Julia version to select (e.g. `"1.11"`), used when
  `julia_home` is not given; resolved to a juliaup-managed install.
  Forwarded to
  [`run_jl_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_jl_step.md).
  Default `NULL` uses the computer/global Julia.

- julia_home, julia_project, julia_packages:

  Julia environment selection, forwarded to
  [`run_jl_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_jl_step.md).
  `julia_home` is the directory containing the julia executable
  (defaults to `getOption("tarpolyglot.julia_home")`; when unset and no
  `julia_version`, JuliaCall discovers Julia on `PATH`). `julia_project`
  is a Julia project environment to `Pkg.activate()`. `julia_packages`
  is a character vector of packages to `using` before the script.

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

## See also

[`tar_target_jl_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl_raw.md),
[`run_jl_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_jl_step.md),
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md)

## Examples

``` r
if (FALSE) { # \dontrun{
list(
  tarpolyglot::tar_target_jl(
    name = jl_sum,
    script = "scripts/sum.jl",
    inputs = c(x = "prepared_x"),
    post_script = "scripts/post.R"
  )
)
} # }
```
