# Live JuliaCall round-trips for inline code (tar_code()). Gated like the other
# integration tests.

skip_if(
  Sys.getenv("TARPOLYGLOT_INTEGRATION") != "true",
  "set TARPOLYGLOT_INTEGRATION=true to run live Julia tests"
)
skip_if_not_installed("JuliaCall")

julia_ok <- tryCatch({
  JuliaCall::julia_setup(installJulia = FALSE, verbose = FALSE)
  TRUE
}, error = function(e) FALSE)
skip_if_not(julia_ok, "no Julia available")

test_that("inline Julia (single line) round-trips", {
  out <- run_jl_step(
    script = tar_code("result = sum(x)"),
    pre_script = tar_code({ to_jl <- list(x = x) }),
    inputs = list(x = c(1, 2, 3)), retrieve = "result"
  )
  expect_equal(out, 6)
})

test_that("inline Julia (multiline) round-trips", {
  out <- run_jl_step(
    script = tar_code("
      function f(v)
          sum(v)
      end
      result = f(x)
    "),
    pre_script = tar_code({ to_jl <- list(x = x) }),
    inputs = list(x = c(1, 2, 3, 4)), retrieve = "result"
  )
  expect_equal(out, 10)
})
