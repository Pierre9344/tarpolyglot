# Get started with tarpolyglot

tarpolyglot lets you run **Python**, **Julia**, and **Rust** code as
ordinary steps of a [`targets`](https://docs.ropensci.org/targets/)
pipeline. It adds three pairs of target constructors that mirror
[`targets::tar_target()`](https://docs.ropensci.org/targets/reference/tar_target.html)
/
[`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html):

| Language | Non-standard eval (in `_targets.R`) | Raw (inside factories) | Bridge |
|----|----|----|----|
| Python | [`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md) | [`tar_target_py_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py_raw.md) | reticulate |
| Julia | [`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md) | [`tar_target_jl_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl_raw.md) | JuliaCall |
| Rust | [`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md) | [`tar_target_rs_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs_raw.md) | rextendr / extendr |

Every code block below is shown for illustration and **is not executed**
when the vignette is built (running it would need a live
Python/Julia/Rust toolchain and a `_targets.R` project). Copy the pieces
into your own pipeline.

## Motivation

If you already work in `targets`, you usually want to keep *all* of its
machinery (dynamic branching, cues and invalidation, storage formats,
`crew`-based parallelism, `tarchetypes`) while occasionally dropping
into Python or Julia for a step or two, or writing a hot function in
Rust. [rixpress](https://github.com/ropensci/rixpress) is a really good
take on polyglot, reproducible pipelines, but it builds those pipelines
on **Nix**-managed environments which could be difficult to implement in
some case (e.g. a public cluster on which you can’t install nix, a
windows computer on which you don’t wish to install wsl).

Doing that by hand means, in every single step, repeating the same
plumbing: initialise reticulate against the right environment, push your
R objects into Python, run the script, convert the results back, and the
equivalent dance for JuliaCall, or the
[`rextendr::rust_source()`](https://extendr.github.io/rextendr/reference/rust_source.html)
setup for Rust. tarpolyglot moves that boilerplate into the constructor.
You point at a script, say which upstream targets feed it and what to
read back, and you get a normal `targets` target:

``` r

library(targets)
library(tarpolyglot)

list(
  tar_target(values, c(2, 4, 6, 8)),
  tar_target_py(
    name = py_mean,
    script = "py/mean.py",           # your Python, unchanged
    inputs = c(x = "values"),        # wire in an upstream target
    pre_script = "R/push.R",         # hand `x` to Python
    retrieve = "result"              # read the Python `result` back into R
  )
)
```

No `reticulate::use_*()`, no manual conversion, no bespoke wrapper per
step, and the environment/version selection (virtualenv, venv, uv,
poetry, conda for Python; juliaup and Julia projects for Julia; rustup
toolchains for Rust) is just another argument. You keep every `targets`
feature and pick your own environment manager, without adopting a
separate build tool such as Nix.

## Installation

``` r

# install.packages("remotes")
remotes::install_local("path/to/tarpolyglot", build_vignettes = TRUE)
```

You then need a working toolchain only for the language(s) you actually
use (each is independent):

- **Python**: any recent CPython, plus `install.packages("reticulate")`.
  reticulate can also provision an ephemeral Python for you via
  [uv](https://docs.astral.sh/uv/).
- **Julia**: install via
  [juliaup](https://github.com/JuliaLang/juliaup), plus
  `install.packages("JuliaCall")`.
- **Rust**: install the toolchain with
  [rustup](https://rust-lang.org/tools/install/) (on **Windows use the
  GNU toolchain**), plus `install.packages("rextendr")`.

See the per-language vignettes for the details:
[`vignette("python")`](https://pierre9344.github.io/tarpolyglot/articles/python.md),
[`vignette("julia")`](https://pierre9344.github.io/tarpolyglot/articles/julia.md),
[`vignette("rust")`](https://pierre9344.github.io/tarpolyglot/articles/rust.md).

## Limitations to know first

tarpolyglot is a thin bridge, so it inherits the constraints of the
runtimes it wraps. The important ones:

1.  **One interpreter per R session.** reticulate binds a single Python
    per R process, and JuliaCall a single Julia, fixed on the first
    call. A second step in the *same* session that asks for a different
    environment silently runs in the first one. To use different
    environments in one pipeline, put those steps on **separate `crew`
    workers** (see below). *(Rust is exempt: each Rust step compiles its
    own library, so different steps can use different crates freely.)*

2.  **Foreign global state is shared within a session.** The Python
    script runs in `__main__` and the Julia script in `Main`. As such, a
    step running on `main` will re-initialises the interpreter of
    previous tarpolyglot steps that were running on main. This results
    in the variables left behing by previous steps to be visible by
    later step in the same session. Never rely on it and always pass
    data explicitly (`inputs` + `to_py`/`to_jl`) and read results back
    with `retrieve` or a post-script.

3.  **Start-up cost vs isolation.** A fresh process re-initialises the
    interpreter (and, on the default ephemeral env, may fetch packages).
    The recommended
    [`polyglot_controller()`](https://pierre9344.github.io/tarpolyglot/reference/polyglot_controller.md)
    gives each target a fresh interpreter (`tasks_max = 1`) for maximum
    isolation; raise `tasks_max` to reuse interpreters for throughput,
    at the cost of the shared-session caveats in points 1–2.

4.  **Only serialisable R values cross target boundaries.** A step can
    return an R object produced by conversion, or **file paths**
    (`output = "file"`). A live Python/Julia object (an open handle, an
    in-memory model) cannot be a target value. You can eventually write
    it to disk in one step and load it in the next.

5.  **Reproducibility is on you.** The default ephemeral Python drifts
    over time; pin a real environment (`env` + `env_manager`, or
    `python`) and, for Julia, a `julia_project` with a committed
    `Manifest.toml`. You should also make sure to use some targets steps
    to keep track of your script files.

## A worked pipeline (Python + iris)

This section builds one small pipeline that exercises the features you
will use most: passing data (including a reproducible **seed**) into
Python, reading variables back in a post-script, tracking the scripts as
dependencies, and returning results either as an in-pipeline object or
as files on disk.

### The three-script model

A Python (or Julia) step is up to three scripts:

     upstream targets ─► pre_script (R) ─► script (.py) ─► post_script (R) ─► target value
                         builds `to_py`     computes         reads `py$name` /
                                            `result`         `py_get("name")`

- **`script`** (required): your Python/Julia file.
- **`pre_script`** (optional R): runs first; the `inputs` are already
  bound by name. Assign a named list `to_py` (Python) / `to_jl` (Julia)
  to push objects into the foreign session.
- **`post_script`** (optional R): runs last; reads results back. Its
  last expression becomes the target value (object mode), or it returns
  file paths (file mode).

### Object output: return a value into the pipeline

`py/iris_kmeans.py` (a small, seeded computation on iris):

``` python
import numpy as np

# `df` (a pandas DataFrame) and `seed` (an int) were pushed from R.
rng = np.random.default_rng(seed)
X = df[["Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width"]].to_numpy()

# pick 3 random initial centres, reproducibly (same seed -> same pick)
idx = rng.choice(X.shape[0], size=3, replace=False)
result = {"n": int(X.shape[0]), "centers": X[idx].tolist()}
```

`R/iris_pre.R`: the pre-script builds `to_py`, and gets the target’s
**reproducible seed** straight from `targets`:

``` r

# `df` is bound from inputs = c(df = "iris_data").
# tar_seed_get() returns THIS target's deterministic seed (derived from the
# pipeline seed and the target name), so the Python RNG is reproducible.
to_py <- list(
  df   = df,
  seed = targets::tar_seed_get()
)
```

`R/iris_post.R`: the post-script reads variables back. tarpolyglot binds
`py` (the reticulate `__main__` proxy) and `py_get(name)` (an explicit
[`reticulate::py_to_r()`](https://rstudio.github.io/reticulate/reference/r-py-conversion.html)
shortcut). The last expression is the target’s value:

``` r

res <- py_get("result")               # or: res <- py$result
data.frame(n = res$n, k = length(res$centers))
```

`_targets.R`:

``` r

library(targets)
library(tarpolyglot)

list(
  tar_target(iris_data, iris),

  tar_target_py(
    name = km,
    script = "py/iris_kmeans.py",
    inputs = c(df = "iris_data"),
    pre_script = "R/iris_pre.R",
    post_script = "R/iris_post.R"       # returns a data.frame into the pipeline
  )
)
```

If all you need is to read one or more variables verbatim (no
reshaping), drop the post-script and use `retrieve` instead: it does the
`py_get()` lookup for you:

``` r

tar_target_py(
  name = km,
  script = "py/iris_kmeans.py",
  inputs = c(df = "iris_data"),
  pre_script = "R/iris_pre.R",
  retrieve = "result"                   # returns the Python `result` as an R list
)
```

### File output: return paths to files on disk

When the script *writes* its output (a CSV, a model, a figure), set
`output = "file"`. The target `format` becomes `"file"` automatically,
and `targets` tracks the returned paths by hash.

`py/iris_write.py`:

``` python
import pandas as pd
out_path = "out/iris_summary.csv"
df.groupby("Species").mean().to_csv(out_path)   # `df` pushed from R
```

`R/iris_files_post.R` (returns the path(s) the step produced):

``` r

py_get("out_path")                      # a character vector of file paths
```

``` r

tar_target_py(
  name = iris_csv,
  script = "py/iris_write.py",
  inputs = c(df = "iris_data"),
  pre_script = "R/iris_pre.R",
  post_script = "R/iris_files_post.R",
  output = "file"                        # target tracks the CSV on disk
)
```

Use file mode for anything that does not round-trip cleanly through
conversion (large arrays, models, non-convertible objects): write it in
one step, load it in the next step’s `pre_script`.

### Tracking the scripts as dependencies

By default `script` / `pre_script` / `post_script` are plain literal
paths: `targets` embeds them as constants, so **editing the file does
not invalidate the target**. To have the step re-run when a script
changes, track that script with its own `format = "file"` target and
reference it with
[`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md):

``` r

list(
  tar_target(iris_data, iris),

  # each script tracked as a file target
  tar_target(kmeans_py,  "py/iris_kmeans.py", format = "file"),
  tar_target(pre_R,      "R/iris_pre.R",      format = "file"),
  tar_target(post_R,     "R/iris_post.R",     format = "file"),

  tar_target_py(
    name = km,
    script      = tar_target_path("kmeans_py"),   # re-runs when the .py changes
    pre_script  = tar_target_path("pre_R"),
    post_script = tar_target_path("post_R"),
    inputs = c(df = "iris_data")
  )
)
```

`tar_target_path("name")` takes the *name* of the upstream file target
(exactly like `inputs = c(x = "some_target")`), so `targets`’ normal
dependency detection picks it up, so there is no need to also list it in
`deps`.

### Parallelism and isolation with crew

Because of limitation 1 (one interpreter per session), the clean way to
give each step a fresh interpreter, and to let different steps use
different environments, is to run them in separate **worker processes**
with [crew](https://wlandau.github.io/crew/). tarpolyglot ships a
controller preconfigured for this:

``` r

tar_option_set(controller = polyglot_controller(workers = 2L))
```

[`polyglot_controller()`](https://pierre9344.github.io/tarpolyglot/reference/polyglot_controller.md)
wraps
[`crew::crew_controller_local()`](https://wlandau.github.io/crew/reference/crew_controller_local.html)
with **`tasks_max = 1L`**: each worker runs one task then retires, so
every foreign step starts from a brand-new interpreter. With a
controller set, tarpolyglot targets (whose `deployment` defaults to
`"worker"`) run on workers automatically.

**Foreign steps on workers, ordinary R steps on the main process.** This
is the common setup: the heavy R work stays in-process, and only the
Python/Julia/Rust steps go to the controller. Flip the global default to
`deployment = "main"` and override just the foreign steps back to
`"worker"`:

``` r

tar_option_set(
  controller = polyglot_controller(workers = 1L),
  deployment = "main"                    # every ordinary tar_target() stays on main
)

list(
  tar_target(iris_data, iris),           # main process
  tar_target_py(
    name = km,
    script = "py/iris_kmeans.py",
    inputs = c(df = "iris_data"),
    pre_script = "R/iris_pre.R",
    retrieve = "result",
    deployment = "worker"                # THIS step runs on the polyglot worker
  )
)
```

The per-step `deployment = "worker"` is required here: without it the
Python step would also inherit `"main"` and run in-process, with no
interpreter isolation.

**Foreign and R steps on different workers.** Use a named
[`crew::crew_controller_group()`](https://wlandau.github.io/crew/reference/crew_controller_group.html)
and route each target by controller name; set the R controller as the
default via `resources` so ordinary targets need no extra argument:

``` r

tar_option_set(
  controller = crew::crew_controller_group(
    polyglot_controller(name = "poly", workers = 2L),          # Python/Julia/Rust
    crew::crew_controller_local(name = "rmain", workers = 4L)  # ordinary R targets
  ),
  resources = tar_resources(crew = tar_resources_crew(controller = "rmain"))
)

list(
  tar_target(iris_data, iris),           # -> "rmain" (the default)
  tar_target_py(
    name = km,
    script = "py/iris_kmeans.py",
    inputs = c(df = "iris_data"),
    pre_script = "R/iris_pre.R",
    retrieve = "result",
    resources = tar_resources(crew = tar_resources_crew(controller = "poly"))
  )
)
```

**Dynamic branching** works unchanged: `inputs` become real
dependencies, so `pattern` branches them, and crew spreads the branches
across workers (each a fresh interpreter under `tasks_max = 1`):

``` r

list(
  tar_target(iris_groups, split(iris, iris$Species), iteration = "list"),  # 3 groups
  tar_target_py(
    name = per_species,
    script = "py/iris_kmeans.py",
    inputs = c(df = "iris_groups"),
    pre_script = "R/iris_pre.R",
    retrieve = "result",
    pattern = map(iris_groups),          # one branch per species, in parallel
    iteration = "list"
  )
)
```

See
[`vignette("python")`](https://pierre9344.github.io/tarpolyglot/articles/python.md),
[`vignette("julia")`](https://pierre9344.github.io/tarpolyglot/articles/julia.md),
and
[`vignette("rust")`](https://pierre9344.github.io/tarpolyglot/articles/rust.md)
for the full per-language reference, and
[`?polyglot_controller`](https://pierre9344.github.io/tarpolyglot/reference/polyglot_controller.md)
for the controller options.

## Pre- and post-scripts: moving variables in and out

The pre- and post-scripts are the two hooks where you move data between
R and the foreign session. They are ordinary R scripts, evaluated in the
step’s environment.

### Sending variables in (the pre-script)

The pre-script runs **before** the foreign script, with the `inputs`
already bound by name. If it assigns a named list called `to_py`
(Python) or `to_jl` (Julia), tarpolyglot pushes each element into the
foreign session:

- **Python**: each element becomes a top-level variable in the
  `__main__` module (via reticulate’s conversion rules).
- **Julia**: each element is `julia_assign()`ed as a variable in `Main`.

``` r

# R/iris_pre.R  (inputs = c(df = "iris_data"))
to_py <- list(
  df   = df,                       # R data.frame -> pandas DataFrame
  seed = targets::tar_seed_get(),  # reproducible integer for the Python RNG
  k    = 3L                        # note the L: Python wants an int, not a double
)
```

Check the reticulate / JuliaCall conversion rules for which R types
round-trip; for anything that does not, use file mode.

### Reading variables out (the post-script)

The post-script runs **after** the foreign script. tarpolyglot binds a
few helpers into its environment:

- **Python steps**: `py`, the reticulate `__main__` proxy (`py$result`),
  and `py_get("result")`, a shortcut for
  `reticulate::py_to_r(py[["result"]])` that forces an explicit
  conversion.
- **Julia steps**: `jl_get("name")`, a shortcut for
  `JuliaCall::julia_eval("name")` (JuliaCall has no `py`-style proxy),
  and `jl_call`, an alias of
  [`JuliaCall::julia_call()`](https://rdrr.io/pkg/JuliaCall/man/call.html).

``` r

# R/iris_post.R  (Python)
res <- py_get("result")
data.frame(n = res$n, k = length(res$centers))   # last expression = target value
```

Rust is different: it has **no pre-script**. The `#[extendr]` functions
are compiled and then called directly from the post-script, with the
`inputs` in scope. See
[`vignette("rust")`](https://pierre9344.github.io/tarpolyglot/articles/rust.md).

## Where to next

- [`vignette("python")`](https://pierre9344.github.io/tarpolyglot/articles/python.md):
  every
  [`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md)
  argument, choosing an environment (system / virtualenv / venv / uv /
  poetry / conda) or a `python_version`, with use-case examples.
- [`vignette("julia")`](https://pierre9344.github.io/tarpolyglot/articles/julia.md):
  the same for Julia (`julia_version`, `julia_project`,
  `julia_packages`).
- [`vignette("rust")`](https://pierre9344.github.io/tarpolyglot/articles/rust.md):
  Rust steps via rextendr/extendr.
- [`?tar_target_py`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md),
  [`?tar_target_jl`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md),
  [`?tar_target_rs`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md),
  [`?tar_target_path`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md),
  [`?polyglot_controller`](https://pierre9344.github.io/tarpolyglot/reference/polyglot_controller.md):
  the function reference.
