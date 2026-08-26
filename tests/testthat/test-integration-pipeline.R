# End-to-end pipelines. Everything else exercises the workers directly; these
# go through the whole path a user actually takes: a constructor in
# _targets.R, the command it generates, targets building the DAG, the worker
# running, and the value coming back through tar_read(). That also covers the
# constructor-time rewriting of `inputs` and tar_target_path() references,
# which only happens when targets sources the pipeline.
#
# targets::tar_test() is the upstream helper meant for downstream packages: it
# runs each block in a throwaway directory (tar_dir()), resets tar_option_*
# before and after so nothing leaks between tests, and cleans up any stray
# worker processes.
#
# Gated like the other live tests; requires tarpolyglot to be installed (it is
# under covr and in CI), since _targets.R is sourced in a fresh targets context.

skip_if(
  Sys.getenv("TARPOLYGLOT_INTEGRATION") != "true",
  "set TARPOLYGLOT_INTEGRATION=true to run live pipeline tests"
)
skip_if_not_installed("targets")

targets::tar_test("a one-step Python pipeline builds and returns its value", {
  skip_if_not_installed("reticulate")
  skip_if_not(reticulate::py_available(initialize = TRUE), "no Python available")
  writeLines(c(
    'library(targets)',
    'list(',
    '  tar_target(prepared_x, c(1, 2, 3, 4)),',
    '  tarpolyglot::tar_target_py(',
    '    name = py_total,',
    '    inputs = c(x = "prepared_x"),',
    '    pre_script = tarpolyglot::tar_code({ to_py <- list(x = x) }),',
    '    script = tarpolyglot::tar_code("result = float(sum(x))"),',
    '    retrieve = "result"',
    '  )',
    ')'
  ), "_targets.R")
  targets::tar_make(reporter = "silent")
  expect_equal(targets::tar_read(py_total), 10)
})

targets::tar_test("a one-step Julia pipeline builds and returns its value", {
  skip_if_not_installed("JuliaCall")
  # Same guard as test-integration-julia.R: julia may be reachable through
  # juliaup or JULIA_HOME without being on PATH, so ask JuliaCall directly.
  julia_ok <- tryCatch({
    JuliaCall::julia_setup(installJulia = FALSE, verbose = FALSE)
    TRUE
  }, error = function(e) FALSE)
  skip_if_not(julia_ok, "no Julia available")
  writeLines(c(
    'library(targets)',
    'list(',
    '  tar_target(prepared_x, c(1, 2, 3, 4)),',
    '  tarpolyglot::tar_target_jl(',
    '    name = jl_total,',
    '    inputs = c(x = "prepared_x"),',
    '    pre_script = tarpolyglot::tar_code({ to_jl <- list(x = x) }),',
    '    script = tarpolyglot::tar_code("result = sum(x)"),',
    '    retrieve = "result"',
    '  )',
    ')'
  ), "_targets.R")
  targets::tar_make(reporter = "silent")
  expect_equal(targets::tar_read(jl_total), 10)
})

targets::tar_test("a one-step C++ pipeline builds and returns its value", {
  skip_if_not_installed("Rcpp")
  writeLines(c(
    'library(targets)',
    'list(',
    '  tar_target(prepared_x, c(1, 2, 3, 4)),',
    '  tarpolyglot::tar_target_cpp(',
    '    name = cpp_total,',
    '    inputs = c(x = "prepared_x"),',
    '    script = tarpolyglot::tar_code(paste(',
    '      "#include <Rcpp.h>",',
    '      "// [[Rcpp::export]]",',
    '      "double total(Rcpp::NumericVector v) { return Rcpp::sum(v); }",',
    '      sep = "\\n")),',
    '    post_script = tarpolyglot::tar_code({ total(x) })',
    '  )',
    ')'
  ), "_targets.R")
  targets::tar_make(reporter = "silent")
  expect_equal(targets::tar_read(cpp_total), 10)
})

targets::tar_test("a one-step Rust pipeline builds and returns its value", {
  skip_if_not_installed("rextendr")
  # Same guard as test-integration-rust.R: cargo is often installed under
  # ~/.cargo/bin without being on PATH; run_rs_step() puts it there itself.
  cargo_ok <- nzchar(Sys.which("cargo")) ||
    file.exists(file.path(Sys.getenv("USERPROFILE", Sys.getenv("HOME")),
      ".cargo", "bin", "cargo.exe"))
  skip_if_not(cargo_ok, "cargo not available")
  writeLines(c(
    'library(targets)',
    'list(',
    '  tar_target(prepared_x, 21),',
    '  tarpolyglot::tar_target_rs(',
    '    name = rs_doubled,',
    '    inputs = c(x = "prepared_x"),',
    '    script = tarpolyglot::tar_code(',
    '      "#[extendr] fn double_it(v: f64) -> f64 { 2.0 * v }"),',
    '    post_script = tarpolyglot::tar_code({ double_it(x) })',
    '  )',
    ')'
  ), "_targets.R")
  targets::tar_make(reporter = "silent")
  expect_equal(targets::tar_read(rs_doubled), 42)
})

# The tarpolyglot_*() pattern helpers compile once into a companion
# <name>_cpp_lib / <name>_rust_lib target and reload that library in every
# branch. That reload path (compile_*_lib() + run_*_step_prebuilt(), including
# writing the embedded bytes back out and dyn.load()-ing them) only runs in a
# real branching pipeline, so it needs an end-to-end test rather than a mock.

targets::tar_test("a branching C++ pipeline compiles once and reuses the library", {
  skip_if_not_installed("Rcpp")
  writeLines(c(
    'library(targets)',
    'library(tarpolyglot)',
    'list(',
    '  tar_target(vals, c(1, 2, 3)),',
    '  tar_target_cpp(',
    '    name = squared,',
    '    inputs = c(x = "vals"),',
    '    pattern = tarpolyglot_map(vals),',
    '    script = tar_code(paste(',
    '      "#include <Rcpp.h>",',
    '      "// [[Rcpp::export]]",',
    '      "double sq(double v) { return v * v; }",',
    '      sep = "\\n")),',
    '    post_script = tar_code({ sq(x) })',
    '  )',
    ')'
  ), "_targets.R")
  targets::tar_make(reporter = "silent")

  expect_equal(as.numeric(targets::tar_read(squared)), c(1, 4, 9))
  # The compile-once companion target must exist and hold a reusable bundle.
  expect_true("squared_cpp_lib" %in% targets::tar_manifest()$name)
  lib <- targets::tar_read(squared_cpp_lib)
  expect_s3_class(lib, "tp_cpp_lib")
  expect_true(length(lib$bytes) > 0L)
})

targets::tar_test("a branching Rust pipeline compiles once and reuses the library", {
  skip_if_not_installed("rextendr")
  cargo_ok <- nzchar(Sys.which("cargo")) ||
    file.exists(file.path(Sys.getenv("USERPROFILE", Sys.getenv("HOME")),
      ".cargo", "bin", "cargo.exe"))
  skip_if_not(cargo_ok, "cargo not available")
  writeLines(c(
    'library(targets)',
    'library(tarpolyglot)',
    'list(',
    '  tar_target(vals, c(1, 2, 3)),',
    '  tar_target_rs(',
    '    name = squared,',
    '    inputs = c(x = "vals"),',
    '    pattern = tarpolyglot_map(vals),',
    '    script = tar_code("#[extendr] fn sq(v: f64) -> f64 { v * v }"),',
    '    post_script = tar_code({ sq(x) })',
    '  )',
    ')'
  ), "_targets.R")
  targets::tar_make(reporter = "silent")

  expect_equal(as.numeric(targets::tar_read(squared)), c(1, 4, 9))
  expect_true("squared_rust_lib" %in% targets::tar_manifest()$name)
  lib <- targets::tar_read(squared_rust_lib)
  expect_s3_class(lib, "tp_rust_lib")
  expect_true(length(lib$bytes) > 0L)
})

targets::tar_test("a file-output step records the written file as the target value", {
  skip_if_not_installed("reticulate")
  skip_if_not(reticulate::py_available(initialize = TRUE), "no Python available")
  writeLines(c(
    'library(targets)',
    'list(',
    '  tarpolyglot::tar_target_py(',
    '    name = written,',
    '    output = "file",',
    '    script = tarpolyglot::tar_code(paste(',
    '      "out_path = \'out.txt\'",',
    '      "open(out_path, \'w\').write(\'hello\')",',
    '      sep = "\\n")),',
    '    post_script = tarpolyglot::tar_code({ py_get("out_path") })',
    '  )',
    ')'
  ), "_targets.R")
  targets::tar_make(reporter = "silent")

  path <- targets::tar_read(written)
  expect_true(file.exists(path))
  expect_identical(readLines(path, warn = FALSE), "hello")
})

targets::tar_test("editing a tar_target_path()-tracked script re-runs the step", {
  skip_if_not_installed("reticulate")
  skip_if_not(reticulate::py_available(initialize = TRUE), "no Python available")

  dir.create("py")
  writeLines("result = float(2 * x)", "py/step.py")
  writeLines(c(
    'library(targets)',
    'list(',
    '  tar_target(prepared_x, 5),',
    '  tar_target(step_py, "py/step.py", format = "file"),',
    '  tarpolyglot::tar_target_py(',
    '    name = py_val,',
    '    script = tarpolyglot::tar_target_path("step_py"),',
    '    inputs = c(x = "prepared_x"),',
    '    pre_script = tarpolyglot::tar_code({ to_py <- list(x = x) }),',
    '    retrieve = "result"',
    '  )',
    ')'
  ), "_targets.R")

  targets::tar_make(reporter = "silent")
  expect_equal(targets::tar_read(py_val), 10)
  expect_length(targets::tar_outdated(), 0L)

  # Editing the tracked script must invalidate the step, not serve a stale value.
  writeLines("result = float(3 * x)", "py/step.py")
  expect_true("py_val" %in% targets::tar_outdated())

  targets::tar_make(reporter = "silent")
  expect_equal(targets::tar_read(py_val), 15)
})

targets::tar_test("a helper file wired in through inputs invalidates the step", {
  skip_if_not_installed("reticulate")
  skip_if_not(reticulate::py_available(initialize = TRUE), "no Python available")

  dir.create("py")
  writeLines("def scale(v):\n    return 2 * v", "py/helper.py")
  writeLines(c(
    "import os, sys",
    "sys.path.insert(0, os.path.dirname(helper_path))",
    "import helper",
    "result = float(helper.scale(x))"
  ), "py/step.py")
  writeLines(c(
    'library(targets)',
    'list(',
    '  tar_target(prepared_x, 5),',
    '  tar_target(helper_file, "py/helper.py", format = "file"),',
    '  tarpolyglot::tar_target_py(',
    '    name = py_val,',
    '    script = "py/step.py",',
    '    inputs = c(x = "prepared_x", helper_path = "helper_file"),',
    '    pre_script = tarpolyglot::tar_code({',
    '      to_py <- list(x = x, helper_path = helper_path)',
    '    }),',
    '    retrieve = "result"',
    '  )',
    ')'
  ), "_targets.R")

  targets::tar_make(reporter = "silent")
  expect_equal(targets::tar_read(py_val), 10)

  # An untracked helper would leave py_val up to date here; `inputs` is what
  # makes the edit count (see vignette("scripts")).
  writeLines("def scale(v):\n    return 3 * v", "py/helper.py")
  expect_true("py_val" %in% targets::tar_outdated())

  targets::tar_make(reporter = "silent")
  expect_equal(targets::tar_read(py_val), 15)
})
