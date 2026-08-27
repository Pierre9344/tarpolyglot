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

  Path to the Rust script with `#[extendr]` functions (required).
  Accepts a literal path, a
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference, or inline code from
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md);
  see the "Script options" section below.

- post_script:

  Path to an R script run after compilation, where the compiled
  functions and `inputs` are in scope. Its last expression is the value
  (object mode); it returns file paths (file mode). Required for object
  mode. Accepts a literal path, a
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

  Optional branching pattern as described in the [targets package
  documentation](https://books.ropensci.org/targets/dynamic.html#patterns),
  as a language object (e.g. `quote(map(x))`), forwarded to
  [`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html).
  The patterns included in the targets package (`map()`,
  [`head()`](https://rdrr.io/r/utils/head.html), ...) are accepted, but
  it is recommended to use the tarpolyglot pattern functions instead, as
  they compile the library once and reuse it across the branches (see
  [`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md),
  [`tarpolyglot_head()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_head.md),
  [`tarpolyglot_tail()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_tail.md),
  [`tarpolyglot_cross()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_cross.md),
  [`tarpolyglot_slice()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_slice.md),
  [`tarpolyglot_sample()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_sample.md)).

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

[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md),
[`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md),
[`run_rs_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_rs_step.md),
[`tar_target_py_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py_raw.md),
[`tar_target_jl_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl_raw.md)

## Examples

``` r
# Building a target does not run it, so these examples need no Rust toolchain.
# scripts/square.rs:
#   #[extendr]
#   fn square(x: f64) -> f64 { x * x }
# scripts/post.R:
#   square(x)
tarpolyglot::tar_target_rs_raw(
  name = "rs_square",
  script = "scripts/square.rs",
  inputs = c(x = "value"),
  post_script = "scripts/post.R"
)
#> <tar_stem> 
#>   name: rs_square 
#>   description:  
#>   command:
#>     tarpolyglot::run_rs_step(script = "scripts/square.rs", 
#>         post_script = "scripts/post.R", inputs = list(x = value), 
#>         output = "object", files = NULL, dependencies = NULL, features = NULL, 
#>         profile = NULL, toolchain = NULL) 
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
tarpolyglot::tar_target_rs_raw(
  name = "demo_literal", script = "rs/step.rs", post_script = "R/post.R"
)
#> <tar_stem> 
#>   name: demo_literal 
#>   description:  
#>   command:
#>     tarpolyglot::run_rs_step(script = "rs/step.rs", post_script = "R/post.R", 
#>         inputs = list(), output = "object", files = NULL, dependencies = NULL, 
#>         features = NULL, profile = NULL, toolchain = NULL) 
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
  targets::tar_target(step_rs, "rs/step.rs", format = "file"),
  tarpolyglot::tar_target_rs_raw(
    name = "demo_tracked",
    script = tarpolyglot::tar_target_path("step_rs"),
    post_script = "R/post.R"
  )
)
#> [[1]]
#> <tar_stem> 
#>   name: step_rs 
#>   description:  
#>   command:
#>     "rs/step.rs" 
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
#>     tarpolyglot::run_rs_step(script = step_rs, post_script = "R/post.R", 
#>         inputs = list(), output = "object", files = NULL, dependencies = NULL, 
#>         features = NULL, profile = NULL, toolchain = NULL) 
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
tarpolyglot::tar_target_rs_raw(
  name = "demo_inline",
  script = tarpolyglot::tar_code("#[extendr] fn one() -> f64 { 1.0 }"),
  post_script = tarpolyglot::tar_code({ one() })
)
#> <tar_stem> 
#>   name: demo_inline 
#>   description:  
#>   command:
#>     tarpolyglot::run_rs_step(script = structure(list(code = "#[extendr] fn one() -> f64 { 1.0 }"), 
#>         class = c("tp_inline", "tp_source")), post_script = structure(list(code = quote({
#>         one()
#>     })), class = c("tp_inline", "tp_expr")), inputs = list(), output = "object", 
#>         files = NULL, dependencies = NULL, features = NULL, profile = NULL, 
#>         toolchain = NULL) 
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
