# Per-step stdout/stderr logging for Python and Julia steps (see tar_polyglot_log() /
# polyglot_controller()). crew launches worker processes before it knows
# which target they will run, so the *configuration* (directories, append,
# header) is stashed as environment variables by polyglot_controller() --
# every worker process it spawns inherits them automatically, the same way
# it inherits any other environment variable -- and the *redirection itself*
# happens inside run_py_step()/run_jl_step(), which do know the step name
# and the resolved toolchain once they are actually running.

#' Configure per-step stdout/stderr logging
#'
#' Passed to [polyglot_controller()]'s `log` argument to write one log file per Python/Julia step: `<name>.out` for stdout, `<name>.err` for stderr, named after the target. \pkg{crew} launches worker processes before it knows which target they will run, so this configuration cannot be applied at worker-launch time; instead `polyglot_controller()` stashes it as environment variables (inherited by every worker process it spawns, the same way any other environment variable is), and [run_py_step()] / [run_jl_step()] read them back and do the actual redirection once they know which step is running and what interpreter it resolved.
#'
#' Rust steps ([tar_target_rs()]) are not covered: \pkg{rextendr}-compiled code writes straight to the OS file descriptor, bypassing the redirection mechanism reticulate/JuliaCall provide for their embedded interpreters. Use \pkg{crew}'s own `options_local(log_directory = ...)` (process-level logging; since `polyglot_controller()` defaults to `tasks_max = 1`, each worker runs exactly one step, so that already gives one log per step, Rust included) if you need Rust step output.
#'
#' C++ steps ([tar_target_cpp()]) **are** covered, with one caveat: `Rcpp::Rcout`/`Rcpp::Rcerr` (the idiomatic Rcpp printing calls) route through R's own output-connection system, so they are captured by an R-level `sink()` redirect the same way `cat()`/`message()` output is (confirmed empirically, including from a fresh \pkg{crew} worker process). Raw `std::cout`/`std::cerr`/`printf()` writes bypass R's connection system entirely and write straight to the OS file descriptor, exactly like Rust's `println!()` -- **not** captured here; use `Rcpp::Rcout`/`Rcpp::Rcerr` in compiled code instead of raw C++ streams if you want step output in these logs.
#'
#' **Branches of one `pattern` share a single log file, language-agnostically.** The log file name is fixed to the *target*'s name at the moment its command is built, before branching happens -- so every branch of a `map()`/`tarpolyglot_map()`-driven step (Python, Julia, or C++ alike) writes to the same `<name>.out`/`<name>.err`, and since `append = FALSE` truncates at the start of *each* branch's run, only the last branch to run leaves its output in the file; earlier branches' output is overwritten, not lost-and-gone from disk but never actually visible. Not specific to C++ -- confirmed while investigating C++ logging, but the same file-per-target-name design applies to every constructor. Use `append = TRUE` to at least keep all branches' output (separated, in run order) instead of losing all but the last, or `crew`'s own `options_local(log_directory = ...)` for a genuinely one-file-per-worker-process log.
#'
#' @param stdout,stderr Directory to write per-step log files into (created if missing), or `NULL` to disable that stream. Default `"./logs/out"` / `"./logs/err"`.
#' @param append If `FALSE` (default), a step's log file is truncated at the start of that step's run, so it only ever holds the latest run's output. If `TRUE`, new output is appended after two blank lines separating it from any prior content, so the file accumulates history across repeated runs.
#' @param header If `TRUE` (default), the stdout file gets a header written before the step's own output: the step name, `date()`, the resolved interpreter's version and path, and whether an explicit environment was used.
#'
#' @return A list with class `tp_log`, for `polyglot_controller(log = ...)`.
#' @seealso [polyglot_controller()]
#' @export
#' @examples
#' \dontrun{
#' targets::tar_option_set(
#'   controller = tarpolyglot::polyglot_controller(
#'     log = tarpolyglot::tar_polyglot_log(stdout = "./logs/out", stderr = "./logs/err")
#'   )
#' )
#' }
tar_polyglot_log <- function(stdout = "./logs/out",
                             stderr = "./logs/err",
                             append = FALSE,
                             header = TRUE) {
  if (!is.null(stdout)) {
    stopifnot("`stdout` must be a single string or NULL" =
      is.character(stdout) && length(stdout) == 1L)
  }
  if (!is.null(stderr)) {
    stopifnot("`stderr` must be a single string or NULL" =
      is.character(stderr) && length(stderr) == 1L)
  }
  structure(
    list(stdout = stdout, stderr = stderr, append = isTRUE(append), header = isTRUE(header)),
    class = "tp_log"
  )
}

# Stash a tar_polyglot_log() config as environment variables, so every worker process
# polyglot_controller() spawns from here on inherits it (processx, which
# crew's local launcher uses, inherits the current process environment by
# default at spawn time). Called from polyglot_controller(); a NULL `log`
# leaves any ambient configuration untouched.
.tp_log_set_env <- function(log) {
  if (is.null(log)) return(invisible(NULL))
  if (!inherits(log, "tp_log")) {
    stop("`log` must be created with tarpolyglot::tar_polyglot_log().", call. = FALSE)
  }
  Sys.setenv(
    TARPOLYGLOT_LOG_STDOUT = if (is.null(log$stdout)) "" else log$stdout,
    TARPOLYGLOT_LOG_STDERR = if (is.null(log$stderr)) "" else log$stderr,
    TARPOLYGLOT_LOG_APPEND = as.character(isTRUE(log$append)),
    TARPOLYGLOT_LOG_HEADER = as.character(isTRUE(log$header))
  )
  invisible(NULL)
}

# Read the logging configuration back from the environment variables
# polyglot_controller() set. Returns NULL (logging disabled) when neither
# stream has a directory configured.
.tp_log_get_config <- function() {
  stdout_dir <- Sys.getenv("TARPOLYGLOT_LOG_STDOUT", "")
  stderr_dir <- Sys.getenv("TARPOLYGLOT_LOG_STDERR", "")
  if (!nzchar(stdout_dir) && !nzchar(stderr_dir)) return(NULL)
  list(
    stdout = if (nzchar(stdout_dir)) stdout_dir else NULL,
    stderr = if (nzchar(stderr_dir)) stderr_dir else NULL,
    append = identical(Sys.getenv("TARPOLYGLOT_LOG_APPEND", "FALSE"), "TRUE"),
    header = identical(Sys.getenv("TARPOLYGLOT_LOG_HEADER", "TRUE"), "TRUE")
  )
}

# Prepare `path` for a new step run: truncate it (append = FALSE), or, when
# appending, insert a two-blank-line separator before any prior content.
# Always ends with `path` existing (so later steps can normalizePath() it).
.tp_log_start <- function(path, append) {
  if (is.null(path)) return(invisible(NULL))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (!append) {
    file.create(path)
  } else if (!file.exists(path)) {
    file.create(path)
  } else if (file.info(path)$size > 0) {
    cat("\n\n", file = path, append = TRUE)
  }
  invisible(NULL)
}

# Build this step's log file paths (or NULL if logging is off, or `name` is
# unavailable -- e.g. run_py_step()/run_jl_step() called directly rather than
# through a tar_target_*() constructor), and start (truncate/separate) them.
.tp_log_prepare <- function(log_cfg, name) {
  if (is.null(log_cfg) || is.null(name)) return(NULL)
  out_path <- if (!is.null(log_cfg$stdout)) file.path(log_cfg$stdout, paste0(name, ".out")) else NULL
  err_path <- if (!is.null(log_cfg$stderr)) file.path(log_cfg$stderr, paste0(name, ".err")) else NULL
  .tp_log_start(out_path, log_cfg$append)
  .tp_log_start(err_path, log_cfg$append)
  list(stdout = out_path, stderr = err_path)
}

.tp_log_write_header <- function(path, name, toolchain, version, tool_path, env_info) {
  if (is.null(path)) return(invisible(NULL))
  lines <- c(
    sprintf("== tarpolyglot step: %s ==", name),
    sprintf("date: %s", date()),
    sprintf("%s version: %s", toolchain, version),
    sprintf("%s path: %s", toolchain, tool_path),
    sprintf("environment: %s", env_info),
    ""
  )
  cat(lines, sep = "\n", file = path, append = TRUE)
  invisible(NULL)
}

# Human-readable description of which Python selection path run_py_step()
# took, for the log header. Mirrors .tp_resolve_python()'s precedence
# (python > environment > python_version > default); kept in sync by hand
# since it only builds descriptive text, not behavior.
.tp_py_env_info <- function(python_version, env, env_manager, python) {
  if (!is.null(python)) {
    return(sprintf("yes, explicit interpreter (python = \"%s\")", python))
  }
  if (!identical(env_manager, "system") || !is.null(env)) {
    return(sprintf("yes, environment (env_manager = \"%s\"%s)", env_manager,
      if (is.null(env)) "" else sprintf(", env = \"%s\"", env)))
  }
  if (!is.null(python_version)) {
    return(sprintf("no, version-pinned only (python_version = \"%s\")", python_version))
  }
  "no (system default interpreter)"
}

.tp_jl_env_info <- function(julia_project) {
  if (!is.null(julia_project) && nzchar(julia_project)) {
    return(sprintf("yes (julia_project = \"%s\")", julia_project))
  }
  "no (global environment)"
}

# Run `fn()` (the Python script call) with sys.stdout/sys.stderr redirected
# to the given paths (opened in append mode -- .tp_log_start() already
# handled truncation/separation for the *step*, so this call always adds on
# after that point, and after any header). No-op passthrough if both paths
# are NULL.
.tp_py_with_redirect <- function(out_path, err_path, fn) {
  if (is.null(out_path) && is.null(err_path)) {
    fn()
    return(invisible(NULL))
  }
  py_builtins <- reticulate::import_builtins(convert = TRUE)
  sys <- reticulate::import("sys", convert = TRUE)
  old_stdout <- sys$stdout
  old_stderr <- sys$stderr
  out_file <- if (!is.null(out_path)) py_builtins$open(out_path, "a") else NULL
  err_file <- if (!is.null(err_path)) py_builtins$open(err_path, "a") else NULL
  on.exit({
    sys$stdout <- old_stdout
    sys$stderr <- old_stderr
    if (!is.null(out_file)) out_file$close()
    if (!is.null(err_file)) err_file$close()
  }, add = TRUE)
  if (!is.null(out_file)) sys$stdout <- out_file
  if (!is.null(err_file)) sys$stderr <- err_file
  fn()
  invisible(NULL)
}

# Julia counterpart of .tp_py_with_redirect(): wraps the script `include()`
# in redirect_stdio(), opening the target log paths in append mode from the
# Julia side (again, after .tp_log_start()/header already prepared them).
# No-op passthrough (plain julia_source()) if both paths are NULL.
#
# The wrapping is written to a temp .jl file and run with julia_source(),
# not built as a julia_command() string: julia_command()/julia_eval() only
# reliably parse a single-line expression (see run_jl_step()'s own inline-
# script handling), and a multi-line `redirect_stdio(...) do ... end` block
# passed that way was observed to mis-parse -- the `include()` line ran
# un-redirected, defeating the whole point.
#
# Each configured stream is opened with `open(path, "a") do io ... end`,
# NOT `redirect_stdio(stdout=open(path, "a")) do ... end`: redirect_stdio()
# only rebinds Base.stdout/stderr for its dynamic extent, it does not take
# ownership of (or flush/close) a stream handed to it -- passing a bare
# open() result that way left the write sitting in Julia's IOStream buffer,
# never flushed to disk. open()'s own do-block form closes (and so flushes)
# the file when *it* exits, which is what actually gets the bytes on disk.
.tp_jl_source_with_redirect <- function(script_path, out_path, err_path) {
  if (is.null(out_path) && is.null(err_path)) {
    JuliaCall::julia_source(script_path)
    return(invisible(NULL))
  }
  script_expr <- normalizePath(script_path, winslash = "/", mustWork = TRUE)
  include_line <- sprintf('include(raw"%s")', script_expr)

  body <- if (!is.null(out_path) && !is.null(err_path)) {
    c(
      sprintf('open(raw"%s", "a") do out_io', normalizePath(out_path, winslash = "/", mustWork = TRUE)),
      sprintf('open(raw"%s", "a") do err_io', normalizePath(err_path, winslash = "/", mustWork = TRUE)),
      'redirect_stdio(stdout=out_io, stderr=err_io) do',
      include_line,
      'end', 'end', 'end'
    )
  } else if (!is.null(out_path)) {
    c(
      sprintf('open(raw"%s", "a") do out_io', normalizePath(out_path, winslash = "/", mustWork = TRUE)),
      'redirect_stdio(stdout=out_io, stderr=stderr) do',
      include_line,
      'end', 'end'
    )
  } else {
    c(
      sprintf('open(raw"%s", "a") do err_io', normalizePath(err_path, winslash = "/", mustWork = TRUE)),
      'redirect_stdio(stdout=stdout, stderr=err_io) do',
      include_line,
      'end', 'end'
    )
  }

  wrapper <- tempfile(fileext = ".jl")
  on.exit(unlink(wrapper), add = TRUE)
  writeLines(body, wrapper)
  JuliaCall::julia_source(wrapper)
  invisible(NULL)
}

# C++ counterpart of .tp_py_with_redirect()/.tp_jl_source_with_redirect(): an
# R-level sink() redirect, not a language-side one -- there is no separate
# interpreter object to swap here, and there's nothing to wrap at "script run"
# time either, since compiling a C++ script (Rcpp::sourceCpp()) does not call
# any of the compiled functions. Output only happens once the post-script
# actually calls into compiled code, so `fn` here is that whole downstream
# step (typically a .tp_cpp_finish() call), not just the compile step.
#
# Confirmed empirically (see the point-11 investigation) that Rcpp::Rcout is
# captured by sink(type = "output") and Rcpp::Rcerr by sink(type = "message"),
# in-session and from a fresh callr/crew-worker-like subprocess alike -- Rcout
# routes through R's own output-connection system, unlike raw std::cout/
# std::cerr/printf(), which write straight to the OS file descriptor and so
# are NOT captured by this (exactly like Rust's println!(), see
# .tp_rs_with_redirect()'s absence -- Rust has no equivalent at all).
#
# sink() is a stack (per type), so the two push calls and the two pop calls
# must nest correctly: output pushed first (outermost), message pushed second
# (innermost) -- popped in the reverse order, message then output, inside one
# on.exit() block so a mid-`fn()` error still unwinds both cleanly.
.tp_cpp_with_redirect <- function(out_path, err_path, fn) {
  if (is.null(out_path) && is.null(err_path)) {
    return(fn())
  }
  out_con <- if (!is.null(out_path)) file(out_path, "a") else NULL
  err_con <- if (!is.null(err_path)) file(err_path, "a") else NULL
  if (!is.null(out_con)) sink(out_con, type = "output")
  if (!is.null(err_con)) sink(err_con, type = "message")
  on.exit({
    if (!is.null(err_con)) sink(type = "message")
    if (!is.null(out_con)) sink(type = "output")
    if (!is.null(err_con)) close(err_con)
    if (!is.null(out_con)) close(out_con)
  }, add = TRUE)
  fn()
}

# Human-readable description of the depends = extension packages a C++ step
# was compiled with, for the log header. Mirrors .tp_py_env_info()/
# .tp_jl_env_info() in shape.
.tp_cpp_env_info <- function(depends) {
  if (is.null(depends) || !length(depends)) {
    return("no Rcpp::depends() extension packages")
  }
  sprintf("yes, depends = %s", paste(depends, collapse = ", "))
}
