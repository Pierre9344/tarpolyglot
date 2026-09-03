# Target that runs a Rust script (raw / factory form)

Character-based constructor mirroring
[`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html)
for Rust, for use inside targets factories. Returns a single `targets`
target whose command compiles the `#[extendr]` functions in `script`
with
[`rextendr::rust_source()`](https://extendr.github.io/rextendr/reference/rust_source.html)
and then evaluates an R **post-script** that calls those functions (with
the upstream `inputs` in scope) and returns the value. See
[`run_rs_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step.md)
for the contract. For direct use in `_targets.R`, see
[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md).

## Usage

``` r
tar_target_rs_raw(
  name,
  script,
  post_script = NULL,
  inputs = NULL,
  output = "object",
  files = NULL,
  dependencies = NULL,
  features = NULL,
  profile = NULL,
  toolchain = NULL,
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

  Path to the Rust script with `#[extendr]` functions (required). Either
  a literal string (an untracked path: editing the file does not
  invalidate the target) or a
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference to an upstream target (typically `format = "file"`), which
  makes this step re-run whenever that file changes.

- post_script:

  Path to an R script run after compilation, where the compiled
  functions and `inputs` are in scope. Its last expression is the value
  (object mode); it returns file paths (file mode). Required for object
  mode. Accepts a literal string or a
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

- files:

  Optional character vector of file paths to return when no
  `post_script` is supplied in file mode.

- dependencies, features, profile:

  Passed to
  [`rextendr::rust_source()`](https://extendr.github.io/rextendr/reference/rust_source.html):
  crate `dependencies` (named list), Cargo `features`, and build
  `profile`.

- toolchain:

  Optional rustup toolchain (e.g. `"stable-x86_64-pc-windows-gnu"`);
  sets `RUSTUP_TOOLCHAIN` for the build.

- pattern:

  Optional targets dynamic-branching pattern as a language object (e.g.
  `quote(map(x))`), forwarded to
  [`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html).
  Use `quote(tarpolyglot_map(x))` to compile the crate once and reuse it
  across branches (see
  [`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md)).

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

A `targets` target object. When `pattern` uses
[`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md)
it is instead a list of two targets: the `<name>_rust_lib` compile
target and the branched `<name>` target.

## Details

Unlike Python/Julia there is **no pre-script** for Rust: inputs are used
directly in the post-script alongside the compiled functions. A Rust
toolchain and `cargo` are required; on Windows use the GNU toolchain
(see
[`vignette("rust")`](https://pierre9344.github.io/tarpolyglot/articles/rust.md)).

Under dynamic branching, `pattern = map(...)` recompiles the crate in
every branch (Rust has no live interpreter to reuse). Passing a
tarpolyglot pattern helper instead
([`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md),
[`tarpolyglot_cross()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_cross.md),
[`tarpolyglot_slice()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_slice.md),
[`tarpolyglot_head()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_head.md),
[`tarpolyglot_tail()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_tail.md),
[`tarpolyglot_sample()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_sample.md))
compiles the crate **once** in a companion target named
`<name>_rust_lib` and reuses it across all branches; the constructor
then returns *both* targets as a list. See
[`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md).

## See also

[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md),
[`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md),
[`run_rs_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step.md),
[`tar_target_py_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py_raw.md),
[`tar_target_jl_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl_raw.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tarpolyglot::tar_target_rs_raw(
  name = "rs_square",
  script = "scripts/square.rs",     # #[extendr] fn square(x: f64) -> f64
  inputs = c(x = "value"),
  post_script = "scripts/post.R"    # ends on square(x)
)
} # }
```
