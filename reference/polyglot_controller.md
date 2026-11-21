# A crew controller preconfigured for polyglot isolation

Returns a
[`crew::crew_controller_local()`](https://wlandau.github.io/crew/reference/crew_controller_local.html)
tuned for pipelines that run Python or Julia steps. Because reticulate
and JuliaCall embed a **single interpreter per process** (see
`vignette("get_started", package = "tarpolyglot")`), the only way to get
a fresh interpreter per target, and to use different
environments/versions across targets, is process-level isolation.
Passing this controller to
[`targets::tar_option_set()`](https://docs.ropensci.org/targets/reference/tar_option_set.html)
sends targets to separate worker processes; with `tasks_max = 1` each
worker is retired after one task, so every foreign step gets a clean
interpreter that is torn down when the task finishes.

## Usage

``` r
polyglot_controller(
  workers = 2L,
  tasks_max = 1L,
  seconds_idle = 30,
  log = NULL,
  ...
)
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

- log:

  Optional
  [`polyglot_log()`](https://pierre9344.github.io/tarpolyglot/reference/polyglot_log.md)
  object turning on per-step stdout/stderr log files for Python and
  Julia steps (see that function; Rust is not covered). Default `NULL`
  (no logging, the previous behavior).

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

On a system where `crew` cannot build a controller at all, this function
fails with an explanation instead of passing the underlying error
through. The case seen in practice is a nanonext whose TLS layer is
unavailable: `crew` self-tests it whenever a controller is constructed,
even though this controller requests no TLS, and that self-test reports
`"Not supported"`. It arises where nanonext links a system NNG built
without TLS support instead of compiling its bundled copy. The remedy is
to reinstall nanonext on a system where TLS support is available, or to
run the pipeline with no controller at all, which costs only the
per-step interpreter isolation described above.

## See also

[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md),
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md),
[`polyglot_log()`](https://pierre9344.github.io/tarpolyglot/reference/polyglot_log.md)

## Examples

``` r
# Constructing a controller starts no worker process: targets launches them
# when the pipeline runs, so this example needs no Python. It goes through
# try() because a platform whose nanonext has no usable TLS layer cannot
# build a crew controller at all; see the note above.
controller <- try(polyglot_controller(workers = 4L), silent = TRUE)

if (!inherits(controller, "try-error")) {
  inherits(controller, "crew_class_controller")

  # In _targets.R you hand it to targets::tar_option_set(), alongside the
  # steps that will use it. The option is reset here so the example leaves
  # no global state behind.
  targets::tar_option_set(controller = controller)
  list(
    tar_target_py(x, "scripts/step.py", retrieve = "result")
  )
  targets::tar_option_reset()
}
```
