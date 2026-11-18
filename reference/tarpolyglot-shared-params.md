# Shared arguments for tarpolyglot constructors and workers

Shared arguments for tarpolyglot constructors and workers

## Arguments

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
