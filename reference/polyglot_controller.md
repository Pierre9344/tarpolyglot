# A crew controller preconfigured for polyglot isolation

Returns a
[`crew::crew_controller_local()`](https://wlandau.github.io/crew/reference/crew_controller_local.html)
tuned for pipelines that run Python or Julia steps. Because reticulate
and JuliaCall embed a **single interpreter per process** (see
[`vignette("get_started", package = "tarpolyglot")`](https://pierre9344.github.io/tarpolyglot/articles/get_started.md)),
the only way to get a fresh interpreter per target, and to use different
environments/versions across targets, is process-level isolation.
Passing this controller to
[`targets::tar_option_set()`](https://docs.ropensci.org/targets/reference/tar_option_set.html)
sends targets to separate worker processes; with `tasks_max = 1` each
worker is retired after one task, so every foreign step gets a clean
interpreter that is torn down when the task finishes.

## Usage

``` r
polyglot_controller(workers = 2L, tasks_max = 1L, seconds_idle = 30, ...)
```

## Arguments

- workers:

  Integer number of parallel worker processes. Default `2`.

- tasks_max:

  Integer max tasks a worker runs before it is retired (and its embedded
  interpreter torn down). Default `1` for maximum isolation: a fresh
  Python/Julia per target. Raise it (or set `Inf`) to reuse interpreters
  for throughput, accepting that same-language steps on a worker then
  share the foreign global namespace and one environment.

- seconds_idle:

  Numeric seconds an idle worker waits before shutting down. Default
  `30`.

- ...:

  Further arguments passed to
  [`crew::crew_controller_local()`](https://wlandau.github.io/crew/reference/crew_controller_local.html),
  e.g. `seconds_timeout`, `garbage_collection`, or `reset_globals`.

## Value

A `crew` controller object, ready for
`targets::tar_option_set(controller = ...)`.

## Details

This is the recommended default for polyglot pipelines. Put it near the
top of `_targets.R`:

    targets::tar_option_set(controller = tarpolyglot::polyglot_controller())

## See also

[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md),
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# _targets.R
library(targets)
library(tarpolyglot)
tar_option_set(controller = polyglot_controller(workers = 4))
list(
  tar_target_py(x, "scripts/step.py", retrieve = "result")
)
} # }
```
