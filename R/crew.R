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
#' On a system where `crew` cannot build a controller at all, this function fails with an explanation instead of passing the underlying error through. The case seen in practice is a nanonext installed without TLS support: `crew` self-tests nanonext's TLS layer whenever a controller is constructed, even though this controller requests no TLS, and that self-test reports `"Not supported"`. The remedy is to reinstall nanonext on a system where TLS support is available, or to run the pipeline with no controller at all, which costs only the per-step interpreter isolation described above.
#'
#' @param workers Integer number of parallel worker processes. Default `2`.
#' @param tasks_max Integer max tasks a worker runs before it is retired (and its embedded interpreter torn down). Default `1` for maximum isolation: a fresh Python/Julia per target. Raise it (or set `Inf`) to reuse interpreters for throughput, accepting that same-language steps on a worker then share the foreign global namespace and one environment.
#' @param seconds_idle Numeric seconds an idle worker waits before shutting down. Default `30`.
#' @param ... Further arguments passed to [crew::crew_controller_local()], e.g. `seconds_timeout`, `garbage_collection`, or `reset_globals`.
#'
#' @return A `crew` controller object, ready for `targets::tar_option_set(controller = ...)`.
#' @seealso [tar_target_py()], [tar_target_jl()]
#' @export
#' @examples
#' \dontrun{
#' # _targets.R
#' library(targets)
#' library(tarpolyglot)
#' tar_option_set(controller = polyglot_controller(workers = 4))
#' list(
#'   tar_target_py(x, "scripts/step.py", retrieve = "result")
#' )
#' }
polyglot_controller <- function(workers = 2L,
                                tasks_max = 1L,
                                seconds_idle = 30,
                                ...) {
  tryCatch(
    crew::crew_controller_local(
      workers = as.integer(workers),
      tasks_max = as.integer(tasks_max),
      seconds_idle = seconds_idle,
      ...
    ),
    error = function(e) {
      if (.tp_crew_tls_available()) {
        stop(e)
      }
      stop("polyglot_controller() could not create a `crew` controller: ", conditionMessage(e), call. = FALSE)
    }
  )
}

# Is `crew`'s TLS layer usable here?
#
# `crew` routes every controller through nanonext's TLS layer: crew_tls()
# defaults to `validate = TRUE`, and that validation calls
# nanonext::tls_config() as a self-test regardless of `mode`, so it runs even
# for the no-TLS default this package uses. A nanonext built without TLS
# support fails that call with "Not supported", and no controller can be
# created on such a platform. Nothing in tarpolyglot can work around it, so we
# probe for it.
.tp_crew_tls_available <- function() {
  isTRUE(tryCatch({
    crew::crew_tls()
    TRUE
  }, error = function(e) FALSE))
}
