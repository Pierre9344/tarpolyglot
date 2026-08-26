# Live round-trips for per-step logging (tar_polyglot_log() / polyglot_controller(log=)),
# through real run_py_step()/run_jl_step() calls. Gated behind an env var (see
# test-integration-python.R). Logging config is applied the same way
# polyglot_controller(log=) applies it (environment variables), just via
# .tp_log_set_env() directly rather than constructing a real crew controller,
# since run_py_step()/run_jl_step() only ever read the env vars back -- they
# have no idea whether a real controller or a direct call set them.
#   Sys.setenv(TARPOLYGLOT_INTEGRATION = "true"); devtools::test()

skip_if(
  Sys.getenv("TARPOLYGLOT_INTEGRATION") != "true",
  "set TARPOLYGLOT_INTEGRATION=true to run live logging tests"
)
skip_if_not_installed("reticulate")
skip_if_not(reticulate::py_available(initialize = TRUE), "no Python available")

local_log_env <- function(log) {
  withr::local_envvar(TARPOLYGLOT_LOG_STDOUT = NA, TARPOLYGLOT_LOG_STDERR = NA,
    TARPOLYGLOT_LOG_APPEND = NA, TARPOLYGLOT_LOG_HEADER = NA, .local_envir = parent.frame())
  .tp_log_set_env(log)
}

py_print_script <- function() {
  script <- withr::local_tempfile(fileext = ".py", .local_envir = parent.frame())
  writeLines(c(
    "import sys",
    "print('hello stdout from python')",
    "print('hello stderr from python', file=sys.stderr)",
    "result = 1"
  ), script)
  script
}

test_that("run_py_step writes a header + the script's stdout/stderr to per-step files", {
  dir <- withr::local_tempdir()
  local_log_env(tar_polyglot_log(stdout = file.path(dir, "out"), stderr = file.path(dir, "err")))

  out <- run_py_step(py_print_script(), retrieve = "result", name = "py_log_step")
  expect_equal(out, 1)

  out_path <- file.path(dir, "out", "py_log_step.out")
  err_path <- file.path(dir, "err", "py_log_step.err")
  expect_true(file.exists(out_path))
  expect_true(file.exists(err_path))

  out_txt <- paste(readLines(out_path), collapse = "\n")
  expect_match(out_txt, "tarpolyglot step: py_log_step", fixed = TRUE)
  expect_match(out_txt, "date:")
  expect_match(out_txt, "Python version:")
  expect_match(out_txt, "Python path:")
  expect_match(out_txt, "environment: no (system default", fixed = TRUE)
  expect_match(out_txt, "hello stdout from python", fixed = TRUE)

  err_txt <- paste(readLines(err_path), collapse = "\n")
  expect_match(err_txt, "hello stderr from python", fixed = TRUE)
  # stderr file gets no header -- only the stdout file does.
  expect_no_match(err_txt, "tarpolyglot step:")
})

test_that("run_py_step overwrites the log by default (append = FALSE)", {
  dir <- withr::local_tempdir()
  local_log_env(tar_polyglot_log(stdout = file.path(dir, "out"), stderr = NULL))

  run_py_step(py_print_script(), retrieve = "result", name = "py_overwrite")
  first_size <- file.info(file.path(dir, "out", "py_overwrite.out"))$size
  run_py_step(py_print_script(), retrieve = "result", name = "py_overwrite")

  txt <- paste(readLines(file.path(dir, "out", "py_overwrite.out")), collapse = "\n")
  expect_equal(lengths(regmatches(txt, gregexpr("hello stdout from python", txt))), 1L)
  expect_equal(file.info(file.path(dir, "out", "py_overwrite.out"))$size, first_size)
})

test_that("run_py_step append = TRUE accumulates with a two-blank-line separator", {
  dir <- withr::local_tempdir()
  local_log_env(tar_polyglot_log(stdout = file.path(dir, "out"), stderr = NULL, append = TRUE))

  run_py_step(py_print_script(), retrieve = "result", name = "py_append")
  run_py_step(py_print_script(), retrieve = "result", name = "py_append")

  lines <- readLines(file.path(dir, "out", "py_append.out"))
  txt <- paste(lines, collapse = "\n")
  expect_equal(lengths(regmatches(txt, gregexpr("hello stdout from python", txt))), 2L)
  # separator: two blank lines somewhere between the two runs.
  blanks <- rle(lines == "")
  expect_true(any(blanks$lengths[blanks$values] >= 2))
})

test_that("run_py_step header = FALSE omits the header block", {
  dir <- withr::local_tempdir()
  local_log_env(tar_polyglot_log(stdout = file.path(dir, "out"), stderr = NULL, header = FALSE))

  run_py_step(py_print_script(), retrieve = "result", name = "py_noheader")
  txt <- paste(readLines(file.path(dir, "out", "py_noheader.out")), collapse = "\n")
  expect_no_match(txt, "tarpolyglot step:")
  expect_match(txt, "hello stdout from python", fixed = TRUE)
})

test_that("run_py_step writes nothing when no log config is set (default, backward compatible)", {
  dir <- withr::local_tempdir()
  local_log_env(NULL)
  withr::local_envvar(TARPOLYGLOT_LOG_STDOUT = "", TARPOLYGLOT_LOG_STDERR = "")

  run_py_step(py_print_script(), retrieve = "result", name = "py_nolog")
  expect_length(list.files(dir, recursive = TRUE), 0L)
})

# --- Julia -------------------------------------------------------------

skip_if_not_installed("JuliaCall")
julia_ok <- tryCatch({
  JuliaCall::julia_setup(installJulia = FALSE, verbose = FALSE)
  TRUE
}, error = function(e) FALSE)

jl_print_script <- function() {
  script <- withr::local_tempfile(fileext = ".jl", .local_envir = parent.frame())
  writeLines(c(
    "println(\"hello stdout from julia\")",
    "result = 1"
  ), script)
  script
}

test_that("run_jl_step writes a header + the script's stdout to a per-step file", {
  skip_if_not(julia_ok, "no Julia available")
  dir <- withr::local_tempdir()
  local_log_env(tar_polyglot_log(stdout = file.path(dir, "out"), stderr = file.path(dir, "err")))

  out <- run_jl_step(jl_print_script(), retrieve = "result", name = "jl_log_step")
  expect_equal(out, 1)

  out_txt <- paste(readLines(file.path(dir, "out", "jl_log_step.out")), collapse = "\n")
  expect_match(out_txt, "tarpolyglot step: jl_log_step", fixed = TRUE)
  expect_match(out_txt, "Julia version:")
  expect_match(out_txt, "Julia path:")
  expect_match(out_txt, "environment: no (global environment)", fixed = TRUE)
  expect_match(out_txt, "hello stdout from julia", fixed = TRUE)
})

test_that("run_jl_step writes nothing when no log config is set", {
  skip_if_not(julia_ok, "no Julia available")
  dir <- withr::local_tempdir()
  local_log_env(NULL)
  withr::local_envvar(TARPOLYGLOT_LOG_STDOUT = "", TARPOLYGLOT_LOG_STDERR = "")

  run_jl_step(jl_print_script(), retrieve = "result", name = "jl_nolog")
  expect_length(list.files(dir, recursive = TRUE), 0L)
})

# --- C++ -----------------------------------------------------------------
# Point 11 of the roadmap's C++ item: Rcpp::Rcout/Rcerr, unlike raw
# std::cout/std::cerr (or Rust's println!()), route through R's own
# output-connection system, so sink() captures them -- confirmed empirically
# and implemented in .tp_cpp_with_redirect() (see R/log.R). These are real
# Rcpp::sourceCpp() compiles, not stubs, exercising the same code path
# run_cpp_step()/run_cpp_step_prebuilt() use in a real pipeline.

skip_if_not_installed("Rcpp")

cpp_loud_script <- function() {
  tar_code("
    #include <Rcpp.h>
    // [[Rcpp::export]]
    double loud_square(double x) {
      Rcpp::Rcout << \"computing square of \" << x << std::endl;
      double result = x * x;
      if (x < 0) Rcpp::Rcerr << \"warning: negative input\" << std::endl;
      return result;
    }
  ")
}

cpp_loud_post <- function() {
  script <- withr::local_tempfile(fileext = ".R", .local_envir = parent.frame())
  writeLines("loud_square(x)", script)
  script
}

test_that("run_cpp_step writes a header + Rcout/Rcerr to per-step files", {
  dir <- withr::local_tempdir()
  local_log_env(tar_polyglot_log(stdout = file.path(dir, "out"), stderr = file.path(dir, "err")))

  out <- run_cpp_step(cpp_loud_script(), post_script = cpp_loud_post(),
    inputs = list(x = -3), name = "cpp_log_step")
  expect_equal(out, 9)

  out_path <- file.path(dir, "out", "cpp_log_step.out")
  err_path <- file.path(dir, "err", "cpp_log_step.err")
  expect_true(file.exists(out_path))
  expect_true(file.exists(err_path))

  out_txt <- paste(readLines(out_path), collapse = "\n")
  expect_match(out_txt, "tarpolyglot step: cpp_log_step", fixed = TRUE)
  expect_match(out_txt, "C++ version: Rcpp", fixed = TRUE)
  expect_match(out_txt, "computing square of -3", fixed = TRUE)

  err_txt <- paste(readLines(err_path), collapse = "\n")
  expect_match(err_txt, "warning: negative input", fixed = TRUE)
})

test_that("run_cpp_step does not capture raw std::cout (only Rcout/Rcerr)", {
  dir <- withr::local_tempdir()
  local_log_env(tar_polyglot_log(stdout = file.path(dir, "out"), stderr = NULL))

  script <- tar_code("
    #include <Rcpp.h>
    // [[Rcpp::export]]
    double raw_cout_fn(double x) {
      std::cout << \"raw cout, not Rcout\" << std::endl;
      return x;
    }
  ")
  post <- withr::local_tempfile(fileext = ".R")
  writeLines("raw_cout_fn(x)", post)

  run_cpp_step(script, post_script = post, inputs = list(x = 1), name = "cpp_raw_cout")
  out_txt <- paste(readLines(file.path(dir, "out", "cpp_raw_cout.out")), collapse = "\n")
  expect_no_match(out_txt, "raw cout, not Rcout")
})

test_that("run_cpp_step writes nothing when no log config is set", {
  dir <- withr::local_tempdir()
  local_log_env(NULL)
  withr::local_envvar(TARPOLYGLOT_LOG_STDOUT = "", TARPOLYGLOT_LOG_STDERR = "")

  run_cpp_step(cpp_loud_script(), post_script = cpp_loud_post(), inputs = list(x = 4),
    name = "cpp_nolog")
  expect_length(list.files(dir, recursive = TRUE), 0L)
})

test_that("run_cpp_step_prebuilt writes Rcout output through the reloaded, re-bound closures", {
  dir <- withr::local_tempdir()
  local_log_env(tar_polyglot_log(stdout = file.path(dir, "out"), stderr = NULL))

  lib <- compile_cpp_lib(cpp_loud_script())
  out <- run_cpp_step_prebuilt(lib, post_script = cpp_loud_post(), inputs = list(x = 6),
    name = "cpp_prebuilt_log")
  expect_equal(out, 36)

  out_txt <- paste(readLines(file.path(dir, "out", "cpp_prebuilt_log.out")), collapse = "\n")
  expect_match(out_txt, "tarpolyglot step: cpp_prebuilt_log", fixed = TRUE)
  expect_match(out_txt, "reused a pre-compiled library", fixed = TRUE)
  expect_match(out_txt, "computing square of 6", fixed = TRUE)
})
