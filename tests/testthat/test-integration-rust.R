# Live Rust round-trip via rextendr/extendr. Gated behind an env var (see the
# Python file); also needs a Rust toolchain (cargo). On Windows the GNU toolchain
# is required. run_rs_step sets up R_HOME / PATH for the build itself.
#   Sys.setenv(TARPOLYGLOT_INTEGRATION = "true"); devtools::test()

skip_if(
  Sys.getenv("TARPOLYGLOT_INTEGRATION") != "true",
  "set TARPOLYGLOT_INTEGRATION=true to run live Rust tests"
)
skip_if_not_installed("rextendr")

cargo_ok <- nzchar(Sys.which("cargo")) ||
  file.exists(file.path(Sys.getenv("USERPROFILE", Sys.getenv("HOME")),
    ".cargo", "bin", "cargo.exe"))
skip_if_not(cargo_ok, "cargo not available")

test_that("run_rs_step compiles #[extendr] fns and returns via post-script", {
  script <- withr::local_tempfile(fileext = ".rs")
  writeLines("#[extendr]\nfn vsum(x: Vec<f64>) -> f64 { x.iter().sum() }", script)
  post <- withr::local_tempfile(fileext = ".R")
  writeLines("list(sum = vsum(x), n = length(x))", post)

  res <- run_rs_step(script, post_script = post, inputs = list(x = c(1, 2, 3, 4)))
  expect_equal(res$sum, 10)
  expect_equal(res$n, 4)
})

test_that("multiple #[extendr] functions in one script are all exposed", {
  script <- withr::local_tempfile(fileext = ".rs")
  writeLines(c(
    "#[extendr] fn inc(x: f64) -> f64 { x + 1.0 }",
    "#[extendr] fn tentimes(x: f64) -> f64 { x * 10.0 }"
  ), script)
  lib <- compile_rs_lib(script)
  expect_true(all(c("inc", "tentimes") %in% names(lib$objs)))
  post <- withr::local_tempfile(fileext = ".R")
  writeLines("c(inc(x), tentimes(x))", post)
  expect_equal(run_rs_step_prebuilt(lib, post_script = post, inputs = list(x = 5)),
    c(6, 50))
})

test_that("two libraries sharing the rextendr module name do not collide", {
  skip_if_not_installed("callr")
  # Compile in fresh processes so both get the per-process module name rextendr1
  # (the collision case). One process then reloads both in turn, as a reused crew
  # worker would.
  compile_fresh <- function(rust) {
    script <- tempfile(fileext = ".rs")
    writeLines(rust, script)
    on.exit(unlink(script), add = TRUE)
    callr::r(function(s) tarpolyglot::compile_rs_lib(s), args = list(script))
  }
  libA <- compile_fresh("#[extendr] fn f(x: f64) -> f64 { x + 1.0 }")
  libB <- compile_fresh("#[extendr] fn f(x: f64) -> f64 { x + 100.0 }")
  expect_identical(libA$basename, libB$basename)  # same module name => collision risk

  post <- withr::local_tempfile(fileext = ".R")
  writeLines("f(x)", post)
  # Hot-swap must give each library its own behaviour, in both directions.
  expect_equal(run_rs_step_prebuilt(libA, post_script = post, inputs = list(x = 5)), 6)
  expect_equal(run_rs_step_prebuilt(libB, post_script = post, inputs = list(x = 5)), 105)
  expect_equal(run_rs_step_prebuilt(libA, post_script = post, inputs = list(x = 5)), 6)
})

test_that("compile_rs_lib() builds a reusable bundle that run_rs_step_prebuilt reloads", {
  script <- withr::local_tempfile(fileext = ".rs")
  writeLines("#[extendr]\nfn square(x: f64) -> f64 { x * x }", script)
  post <- withr::local_tempfile(fileext = ".R")
  writeLines("square(x)", post)

  # Compile once.
  lib <- compile_rs_lib(script)
  expect_s3_class(lib, "tp_rust_lib")
  expect_true(is.raw(lib$bytes) && length(lib$bytes) > 0)
  expect_true("square" %in% names(lib$objs))

  # Reuse it several times with different inputs (this is what each branch does),
  # with no further compilation.
  expect_equal(run_rs_step_prebuilt(lib, post_script = post, inputs = list(x = 10)), 100)
  expect_equal(run_rs_step_prebuilt(lib, post_script = post, inputs = list(x = 20)), 400)
  expect_equal(run_rs_step_prebuilt(lib, post_script = post, inputs = list(x = 30)), 900)
})
