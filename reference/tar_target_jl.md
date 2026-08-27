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

  Path to the Julia script to run (required). Accepts a literal path, a
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference, or inline code from
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md);
  see the "Script options" section below.

- pre_script:

  Optional path to an R script run before the Julia script. See
  [`run_jl_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_jl_step.md);
  assign a named list `to_jl` to hand objects to Julia. Accepts a
  literal path, a
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference, or inline code from
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md);
  see the "Script options" section below.

- post_script:

  Optional path to an R script run after the Julia script. See
  [`run_jl_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_jl_step.md);
  helpers `jl_get()` and `jl_call()` are available, and its last
  expression (object mode) or returned paths (file mode) become the
  value. Accepts a literal path, a
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

[`tar_target_jl_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl_raw.md),
[`run_jl_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_jl_step.md),
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# scripts/sum.jl:
#   result = sum(x)
# scripts/post.R:
#   jl_get("result")
list(
  tarpolyglot::tar_target_jl(
    name = jl_sum,
    script = "scripts/sum.jl",
    inputs = c(x = "prepared_x"),
    post_script = "scripts/post.R"
  )
)

# The three ways to supply a script (see the "Script options" section):
# 1. Literal path: untracked, editing the file does NOT re-run the step.
tarpolyglot::tar_target_jl(
  name = demo_literal, script = "jl/step.jl", retrieve = "result"
)

# 2. tar_target_path(): tracked, editing the file DOES re-run the step.
list(
  targets::tar_target(step_jl, "jl/step.jl", format = "file"),
  tarpolyglot::tar_target_jl(
    name = demo_tracked,
    script = tarpolyglot::tar_target_path("step_jl"),
    retrieve = "result"
  )
)

# 3. tar_code(): inline, editing the code DOES re-run the step. A string
#    carries foreign source; an R { } block carries inline R.
tarpolyglot::tar_target_jl(
  name = demo_inline,
  script = tarpolyglot::tar_code("result = 1 + 1"),
  post_script = tarpolyglot::tar_code({ jl_get("result") })
)

# Tracking a helper file the script includes. Point `inputs` at a
# format = "file" target so editing the helper also re-runs the step;
# `inputs` takes the *target* name, not the path. Julia resolves a
# relative include() against the including file's own directory, so make
# the path absolute. jl/step.jl is then:
#   include(helper_path)
#   result = sum(myscale(x))
list(
  targets::tar_target(helper_file, "jl/helper.jl", format = "file"),
  tarpolyglot::tar_target_jl(
    name = demo_helper,
    script = "jl/step.jl",
    inputs = c(x = "prepared_x", helper_path = "helper_file"),
    pre_script = tarpolyglot::tar_code({
      to_jl <- list(x = x, helper_path = normalizePath(helper_path, winslash = "/"))
    }),
    retrieve = "result"
  )
)
} # }
```
