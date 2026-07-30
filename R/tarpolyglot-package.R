#' tarpolyglot: run Python, Julia, and Rust as targets pipeline steps
#'
#' \if{html}{\figure{logo.png}{options: style='float: right' alt='logo' width='120'}}
#'
#' tarpolyglot provides target constructors that execute Python, Julia, and Rust code inside a [targets](https://docs.ropensci.org/targets/) pipeline, using \pkg{reticulate} (Python), \pkg{JuliaCall} (Julia), and \pkg{rextendr} (Rust).
#'
#' The user-facing constructors mirror the \pkg{targets} pair:
#' * [tar_target_py()] / [tar_target_py_raw()] for Python,
#' * [tar_target_jl()] / [tar_target_jl_raw()] for Julia,
#' * [tar_target_rs()] / [tar_target_rs_raw()] for Rust (compiled via rextendr/extendr; see `vignette("rust")`).
#'
#' The non-`_raw` forms use non-standard evaluation on `name`/`pattern` and are meant for direct use in `_targets.R`; the `_raw` forms take a string `name` and are meant for use inside targets factories. Each constructor returns a single `targets` target object.
#'
#' A Python/Julia step may combine up to three scripts: an optional R **pre-script** (prepare inputs), the required **foreign script**, and an optional R **post-script** (retrieve results). A Rust step has no pre-script: its `#[extendr]` functions are compiled and then called from the R post-script. Output is returned either as a converted R object or as a character vector of files on disk (`output = "file"`).
#'
#' Start with `vignette("get_started")` (motivation, limitations, a worked pipeline, and `crew`-based parallelism/isolation), then the per-language vignettes `vignette("python")`, `vignette("julia")`, and `vignette("rust")`.
#'
#' @keywords internal
"_PACKAGE"
