# Live reticulate round-trips. Gated behind an env var so the default test run
# and R CMD check stay fast and offline. Run with:
#   Sys.setenv(TARPOLYGLOT_INTEGRATION = "true"); devtools::test()

skip_if(
  Sys.getenv("TARPOLYGLOT_INTEGRATION") != "true",
  "set TARPOLYGLOT_INTEGRATION=true to run live Python tests"
)
skip_if_not_installed("reticulate")
skip_if_not(reticulate::py_available(initialize = TRUE), "no Python available")

test_that("run_py_step returns a converted object (retrieve)", {
  script <- withr::local_tempfile(fileext = ".py")
  writeLines(c(
    "seq = list(x) if hasattr(x, '__iter__') else [x]",
    "result = float(sum(seq))"
  ), script)
  pre <- withr::local_tempfile(fileext = ".R")
  writeLines("to_py <- list(x = x)", pre)

  out <- run_py_step(script, pre_script = pre,
    inputs = list(x = c(1, 2, 3)), retrieve = "result")
  expect_equal(out, 6)
})

test_that("run_py_step file mode returns the written path", {
  dir <- withr::local_tempdir()
  script <- withr::local_tempfile(fileext = ".py")
  out_csv <- file.path(dir, "out.csv")
  writeLines(c(
    "import csv",
    sprintf("out_path = r'%s'", out_csv),
    "with open(out_path, 'w', newline='') as f:",
    "    csv.writer(f).writerow(['a', 'b'])"
  ), script)
  post <- withr::local_tempfile(fileext = ".R")
  writeLines("py$out_path", post)

  paths <- run_py_step(script, post_script = post, output = "file")
  expect_true(file.exists(paths))
})
