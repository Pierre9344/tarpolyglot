# Live reticulate round-trips for inline code (tar_code()). Gated like the other
# integration tests. Run with:
#   Sys.setenv(TARPOLYGLOT_INTEGRATION = "true"); devtools::test()

skip_if(
  Sys.getenv("TARPOLYGLOT_INTEGRATION") != "true",
  "set TARPOLYGLOT_INTEGRATION=true to run live Python tests"
)
skip_if_not_installed("reticulate")
skip_if_not(reticulate::py_available(initialize = TRUE), "no Python available")

test_that("inline Python (single line) round-trips", {
  out <- run_py_step(
    script = tar_code("result = float(sum(x))"),
    pre_script = tar_code({ to_py <- list(x = x) }),
    inputs = list(x = c(1, 2, 3)), retrieve = "result"
  )
  expect_equal(out, 6)
})

test_that("inline Python (multiline, indentation-critical) round-trips", {
  # Indented to line up with the R source; tar_code() dedents so the top-level
  # statements are flush-left (otherwise Python raises IndentationError) while the
  # loop body keeps its relative indent.
  out <- run_py_step(
    script = tar_code("
      total = 0.0
      for v in x:
          total += v
      result = total
    "),
    pre_script = tar_code({ to_py <- list(x = x) }),
    inputs = list(x = c(1, 2, 3, 4)), retrieve = "result"
  )
  expect_equal(out, 10)
})
