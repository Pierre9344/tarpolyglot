# Live Rust round-trip for inline code (tar_code()) via rextendr/extendr. Gated like
# the other integration tests; also needs a Rust toolchain (cargo, GNU on Windows).

skip_if(
  Sys.getenv("TARPOLYGLOT_INTEGRATION") != "true",
  "set TARPOLYGLOT_INTEGRATION=true to run live Rust tests"
)
skip_if_not_installed("rextendr")

cargo_ok <- nzchar(Sys.which("cargo")) ||
  file.exists(file.path(Sys.getenv("USERPROFILE", Sys.getenv("HOME")),
    ".cargo", "bin", "cargo.exe"))
skip_if_not(cargo_ok, "cargo not available")

test_that("inline Rust (single line) round-trips", {
  res <- run_rs_step(
    script = tar_code("#[extendr] fn vsum(x: Vec<f64>) -> f64 { x.iter().sum() }"),
    post_script = tar_code({ vsum(x) }),
    inputs = list(x = c(1, 2, 3, 4))
  )
  expect_equal(res, 10)
})

test_that("inline Rust (multiline) round-trips", {
  res <- run_rs_step(
    script = tar_code("
      #[extendr]
      fn vsum(x: Vec<f64>) -> f64 {
          x.iter().sum()
      }
    "),
    post_script = tar_code({ vsum(x) }),
    inputs = list(x = c(1, 2, 3, 4))
  )
  expect_equal(res, 10)
})
