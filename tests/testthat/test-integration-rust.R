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
