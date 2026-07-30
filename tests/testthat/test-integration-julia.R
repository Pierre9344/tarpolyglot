# Live JuliaCall round-trips. Gated behind an env var (see the Python file).
#   Sys.setenv(TARPOLYGLOT_INTEGRATION = "true"); devtools::test()

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

test_that("run_jl_step returns a converted object (retrieve)", {
  script <- withr::local_tempfile(fileext = ".jl")
  writeLines(c(
    "seq = isa(x, AbstractVector) ? x : [x]",
    "result = sum(seq)"
  ), script)
  pre <- withr::local_tempfile(fileext = ".R")
  writeLines("to_jl <- list(x = x)", pre)

  out <- run_jl_step(script, pre_script = pre,
    inputs = list(x = c(1, 2, 3)), retrieve = "result")
  expect_equal(out, 6)
})

test_that("run_jl_step file mode returns the written path", {
  dir <- withr::local_tempdir()
  out_csv <- file.path(dir, "out.csv")
  script <- withr::local_tempfile(fileext = ".jl")
  writeLines(c(
    sprintf('out_path = raw"%s"', out_csv),
    'open(out_path, "w") do io; println(io, "a,b"); end'
  ), script)
  post <- withr::local_tempfile(fileext = ".R")
  writeLines('jl_get("out_path")', post)

  paths <- run_jl_step(script, post_script = post, output = "file")
  expect_true(file.exists(paths))
})
