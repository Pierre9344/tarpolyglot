# Fast/structural tests for tar_polyglot_log() and the per-step logging machinery
# (see R/log.R). No reticulate/JuliaCall/live interpreter needed here -- see
# test-integration-logging.R for real run_py_step()/run_jl_step() round-trips.

test_that("tar_polyglot_log returns a tp_log list with the documented defaults", {
  log <- tar_polyglot_log()
  expect_s3_class(log, "tp_log")
  expect_equal(log$stdout, "./logs/out")
  expect_equal(log$stderr, "./logs/err")
  expect_false(log$append)
  expect_true(log$header)
})

test_that("tar_polyglot_log validates stdout/stderr", {
  expect_error(tar_polyglot_log(stdout = c("a", "b")), "single string")
  expect_error(tar_polyglot_log(stderr = 1), "single string")
  expect_s3_class(tar_polyglot_log(stdout = NULL, stderr = NULL), "tp_log")
})

test_that(".tp_log_set_env / .tp_log_get_config round-trip", {
  withr::local_envvar(TARPOLYGLOT_LOG_STDOUT = NA, TARPOLYGLOT_LOG_STDERR = NA,
    TARPOLYGLOT_LOG_APPEND = NA, TARPOLYGLOT_LOG_HEADER = NA)

  .tp_log_set_env(tar_polyglot_log(stdout = "out/", stderr = "err/", append = TRUE, header = FALSE))
  cfg <- .tp_log_get_config()
  expect_equal(cfg$stdout, "out/")
  expect_equal(cfg$stderr, "err/")
  expect_true(cfg$append)
  expect_false(cfg$header)
})

test_that(".tp_log_set_env(NULL) leaves the environment untouched", {
  withr::local_envvar(TARPOLYGLOT_LOG_STDOUT = "untouched")
  .tp_log_set_env(NULL)
  expect_equal(Sys.getenv("TARPOLYGLOT_LOG_STDOUT"), "untouched")
})

test_that(".tp_log_set_env rejects non-tp_log input", {
  expect_error(.tp_log_set_env(list(stdout = "x")), "tar_polyglot_log")
})

test_that(".tp_log_get_config returns NULL when neither stream is configured", {
  withr::local_envvar(TARPOLYGLOT_LOG_STDOUT = "", TARPOLYGLOT_LOG_STDERR = "")
  expect_null(.tp_log_get_config())
})

test_that("polyglot_controller(log=) sets the env vars a worker would inherit", {
  withr::local_envvar(TARPOLYGLOT_LOG_STDOUT = NA, TARPOLYGLOT_LOG_STDERR = NA,
    TARPOLYGLOT_LOG_APPEND = NA, TARPOLYGLOT_LOG_HEADER = NA)
  ctrl <- polyglot_controller(log = tar_polyglot_log(stdout = "./x", stderr = NULL, append = TRUE))
  on.exit(try(ctrl$terminate(), silent = TRUE), add = TRUE)
  expect_equal(Sys.getenv("TARPOLYGLOT_LOG_STDOUT"), "./x")
  expect_equal(Sys.getenv("TARPOLYGLOT_LOG_STDERR"), "")
  expect_equal(Sys.getenv("TARPOLYGLOT_LOG_APPEND"), "TRUE")
})

test_that(".tp_log_start truncates by default and on repeated non-append runs", {
  path <- withr::local_tempfile()
  writeLines("stale content", path)
  .tp_log_start(path, append = FALSE)
  expect_equal(readLines(path), character(0))
})

test_that(".tp_log_start appends with a two-blank-line separator", {
  path <- withr::local_tempfile()
  writeLines("first run", path)
  .tp_log_start(path, append = TRUE)
  cat("second run\n", file = path, append = TRUE)
  lines <- readLines(path)
  expect_equal(lines, c("first run", "", "", "second run"))
})

test_that(".tp_log_start on a fresh (nonexistent) path just creates it, append or not", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "sub", "step.out")
  .tp_log_start(path, append = TRUE)
  expect_true(file.exists(path))
  expect_equal(file.info(path)$size, 0)
})

test_that(".tp_log_prepare returns NULL without a log config or a name", {
  expect_null(.tp_log_prepare(NULL, "step"))
  expect_null(.tp_log_prepare(list(stdout = "x", stderr = "y", append = FALSE), NULL))
})

test_that(".tp_log_prepare builds <name>.out / <name>.err under the configured dirs", {
  dir <- withr::local_tempdir()
  out_dir <- file.path(dir, "out")
  err_dir <- file.path(dir, "err")
  paths <- .tp_log_prepare(list(stdout = out_dir, stderr = err_dir, append = FALSE), "my_step")
  expect_equal(paths$stdout, file.path(out_dir, "my_step.out"))
  expect_equal(paths$stderr, file.path(err_dir, "my_step.err"))
  expect_true(file.exists(paths$stdout))
  expect_true(file.exists(paths$stderr))
})

test_that(".tp_log_prepare honors a NULL stream (disabled independently)", {
  dir <- withr::local_tempdir()
  paths <- .tp_log_prepare(list(stdout = dir, stderr = NULL, append = FALSE), "s")
  expect_equal(paths$stdout, file.path(dir, "s.out"))
  expect_null(paths$stderr)
})

test_that(".tp_log_write_header writes the expected fields", {
  path <- withr::local_tempfile()
  file.create(path)
  .tp_log_write_header(path, name = "my_step", toolchain = "Python",
    version = "3.12", tool_path = "/usr/bin/python3", env_info = "no (system default)")
  lines <- readLines(path)
  expect_match(lines[[1]], "my_step", fixed = TRUE)
  expect_match(paste(lines, collapse = "\n"), "date:")
  expect_match(paste(lines, collapse = "\n"), "Python version: 3.12", fixed = TRUE)
  expect_match(paste(lines, collapse = "\n"), "Python path: /usr/bin/python3", fixed = TRUE)
  expect_match(paste(lines, collapse = "\n"), "environment: no (system default)", fixed = TRUE)
})

test_that(".tp_log_write_header is a no-op for a NULL path", {
  expect_null(.tp_log_write_header(NULL, "s", "Python", "3.12", "/x", "no"))
})

test_that(".tp_py_env_info describes each selection precedence branch", {
  expect_match(.tp_py_env_info(NULL, NULL, "system", "/usr/bin/python3"), "explicit interpreter")
  expect_match(.tp_py_env_info(NULL, ".venv", "uv", NULL), "environment")
  expect_match(.tp_py_env_info(NULL, ".venv", "uv", NULL), "uv", fixed = TRUE)
  expect_match(.tp_py_env_info("3.12", NULL, "system", NULL), "version-pinned")
  expect_match(.tp_py_env_info(NULL, NULL, "system", NULL), "system default")
})

test_that(".tp_jl_env_info describes project vs global", {
  expect_match(.tp_jl_env_info("./proj"), "yes")
  expect_match(.tp_jl_env_info("./proj"), "proj", fixed = TRUE)
  expect_match(.tp_jl_env_info(NULL), "no")
  expect_match(.tp_jl_env_info(""), "no")
})

test_that(".tp_py_with_redirect is a transparent passthrough when logging is off", {
  called <- FALSE
  .tp_py_with_redirect(NULL, NULL, function() called <<- TRUE)
  expect_true(called)
})

test_that(".tp_jl_source_with_redirect falls back to plain julia_source() when logging is off", {
  # Stub JuliaCall::julia_source so this stays fast/offline (no live Julia).
  called_with <- NULL
  testthat::local_mocked_bindings(
    julia_source = function(path) called_with <<- path,
    .package = "JuliaCall"
  )
  .tp_jl_source_with_redirect("some/script.jl", NULL, NULL)
  expect_equal(called_with, "some/script.jl")
})

test_that(".tp_cpp_with_redirect is a transparent passthrough when logging is off", {
  called <- FALSE
  out <- .tp_cpp_with_redirect(NULL, NULL, function() { called <<- TRUE; 42 })
  expect_true(called)
  expect_equal(out, 42)
})

test_that(".tp_cpp_with_redirect captures cat()/message() output to the configured paths", {
  # No live Rcpp compile needed here: sink() captures ordinary R output the
  # same way it captures Rcpp::Rcout/Rcerr (see test-integration-logging.R
  # for the real Rcout/Rcerr round-trip through a compiled function).
  out_path <- withr::local_tempfile()
  err_path <- withr::local_tempfile()
  file.create(out_path)
  file.create(err_path)

  result <- .tp_cpp_with_redirect(out_path, err_path, function() {
    cat("to stdout\n")
    message("to stderr")
    "value"
  })
  expect_equal(result, "value")
  expect_match(paste(readLines(out_path), collapse = "\n"), "to stdout", fixed = TRUE)
  expect_match(paste(readLines(err_path), collapse = "\n"), "to stderr", fixed = TRUE)
})

test_that(".tp_cpp_with_redirect honors a NULL stream (disabled independently)", {
  out_path <- withr::local_tempfile()
  file.create(out_path)
  .tp_cpp_with_redirect(out_path, NULL, function() cat("only stdout\n"))
  expect_match(paste(readLines(out_path), collapse = "\n"), "only stdout", fixed = TRUE)
})

test_that(".tp_cpp_env_info describes the depends argument", {
  expect_match(.tp_cpp_env_info(NULL), "no Rcpp::depends", fixed = TRUE)
  expect_match(.tp_cpp_env_info(character(0)), "no Rcpp::depends", fixed = TRUE)
  expect_match(.tp_cpp_env_info("RcppArmadillo"), "RcppArmadillo", fixed = TRUE)
  expect_match(.tp_cpp_env_info(c("RcppArmadillo", "RcppEigen")), "RcppArmadillo, RcppEigen", fixed = TRUE)
})
