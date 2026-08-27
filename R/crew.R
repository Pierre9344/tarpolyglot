#' A crew controller preconfigured for polyglot isolation
#'
#' Returns a [crew::crew_controller_local()] tuned for pipelines that run Python or Julia steps. Because reticulate and JuliaCall embed a **single interpreter per process** (see `vignette("get_started", package = "tarpolyglot")`), the only way to get a fresh interpreter per target, and to use different environments/versions across targets, is process-level isolation. Passing this controller to [targets::tar_option_set()] sends targets to separate worker processes; with `tasks_max = 1` each worker is retired after one task, so every foreign step gets a clean interpreter that is torn down when the task finishes.
#'
#' This is the recommended default for polyglot pipelines. Put it near the top of `_targets.R`:
#'
#' ```r
#' targets::tar_option_set(controller = tarpolyglot::polyglot_controller())
#' ```
#'
#' @param workers Integer number of parallel worker processes. Default `2`.
#' @param tasks_max Integer max tasks a worker runs before it is retired (and its embedded interpreter torn down). Default `1` for maximum isolation: a fresh Python/Julia per target. Raise it (or set `Inf`) to reuse interpreters for throughput, accepting that same-language steps on a worker then share the foreign global namespace and one environment.
#' @param seconds_idle Numeric seconds an idle worker waits before shutting down. Default `30`.
#' @param log Optional [tar_polyglot_log()] object turning on per-step stdout/stderr log files for Python and Julia steps (see that function; Rust is not covered). Default `NULL` (no logging, the previous behavior).
#' @param ... Further arguments passed to [crew::crew_controller_local()], e.g. `seconds_timeout`, `garbage_collection`, or `reset_globals`.
#'
#' @return A `crew` controller object, ready for `targets::tar_option_set(controller = ...)`.
#' @seealso [tar_target_py()], [tar_target_jl()], [tar_polyglot_log()]
#' @export
#' @examples
#' # Constructing a controller starts no worker process: targets launches them
#' # when the pipeline runs, so this example needs no Python.
#' controller <- polyglot_controller(workers = 4L)
#' inherits(controller, "crew_class_controller")
#'
#' # In _targets.R you hand it to targets::tar_option_set(), alongside the
#' # steps that will use it. The option is reset here so the example leaves
#' # no global state behind.
#' targets::tar_option_set(controller = controller)
#' list(
#'   tar_target_py(x, "scripts/step.py", retrieve = "result")
#' )
#' targets::tar_option_reset()
polyglot_controller <- function(workers = 2L,
                                tasks_max = 1L,
                                seconds_idle = 30,
                                log = NULL,
                                ...) {
  .tp_log_set_env(log)
  crew::crew_controller_local(
    workers = as.integer(workers),
    tasks_max = as.integer(tasks_max),
    seconds_idle = seconds_idle,
    ...
  )
}
