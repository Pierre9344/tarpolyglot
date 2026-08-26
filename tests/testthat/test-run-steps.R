# Orchestration tests for run_py_step() / run_jl_step(). The interpreter
# binding and the reticulate/JuliaCall calls are mocked, so what is exercised
# here is the worker's own logic: binding `inputs`, running the pre-script and
# handing `to_py`/`to_jl` over, the output modes, and the error branches.
# The real round-trips are covered by test-integration-python.R / -julia.R.

write_file <- function(code, ext) {
  f <- withr::local_tempfile(fileext = ext, .local_envir = parent.frame())
  writeLines(code, f)
  f
}

# ---- Python ---------------------------------------------------------------

mock_python <- function(main = list(result = 42), env = parent.frame()) {
  testthat::local_mocked_bindings(.tp_resolve_python = function(...) invisible(NULL),
    .env = env)
  testthat::local_mocked_bindings(
    import_main = function(...) main,
    py_run_file = function(...) invisible(NULL),
    py_run_string = function(...) invisible(NULL),
    py_to_r = function(x) x,
    .package = "reticulate", .env = env
  )
}

test_that("run_py_step retrieves a single value by name", {
  skip_if_not_installed("testthat", "3.2.0")
  mock_python()
  expect_identical(
    run_py_step(script = write_file("result = 42", ".py"), retrieve = "result"),
    42
  )
})

test_that("run_py_step retrieves several values as a named list", {
  skip_if_not_installed("testthat", "3.2.0")
  mock_python(main = list(a = 1, b = 2))
  out <- run_py_step(script = write_file("pass", ".py"), retrieve = c("a", "b"))
  expect_identical(out, list(a = 1, b = 2))
})

test_that("run_py_step binds inputs and hands `to_py` over from the pre-script", {
  skip_if_not_installed("testthat", "3.2.0")
  # An environment stands in for the __main__ module proxy: `main[[nm]] <- v`
  # works on it exactly as it does on the real reticulate object, so whatever
  # the worker pushes can be read back afterwards.
  main <- new.env(parent = emptyenv())
  testthat::local_mocked_bindings(.tp_resolve_python = function(...) invisible(NULL))
  testthat::local_mocked_bindings(
    import_main = function(...) main,
    py_run_file = function(...) invisible(NULL),
    py_run_string = function(...) invisible(NULL),
    py_to_r = function(x) x,
    .package = "reticulate"
  )

  run_py_step(
    script = write_file("pass", ".py"),
    pre_script = write_file("to_py <- list(doubled = x * 2)", ".R"),
    inputs = list(x = 21),
    post_script = write_file("'done'", ".R")
  )
  expect_identical(get("doubled", envir = main), 42)
})

test_that("run_py_step object mode needs a post-script or retrieve", {
  skip_if_not_installed("testthat", "3.2.0")
  mock_python()
  expect_error(
    run_py_step(script = write_file("pass", ".py")),
    "needs either a `post_script` or `retrieve`"
  )
})

test_that("run_py_step file mode returns `files` and errors when nothing supplies paths", {
  skip_if_not_installed("testthat", "3.2.0")
  mock_python()
  script <- write_file("pass", ".py")
  res <- run_py_step(script = script, output = "file", files = "out.txt")
  expect_match(res[[1L]], "out.txt", fixed = TRUE)
  expect_error(
    run_py_step(script = script, output = "file"),
    "needs a `post_script` returning paths, or `files`"
  )
})

test_that("run_py_step rejects a script that does not exist", {
  expect_error(
    run_py_step(script = "tp-no-such-script-xyz.py"),
    "points to a file that does not exist"
  )
})

# ---- Julia ----------------------------------------------------------------

mock_julia <- function(values = list(result = 42), env = parent.frame()) {
  testthat::local_mocked_bindings(
    .tp_resolve_julia = function(...) invisible(TRUE),
    .tp_jl_source_with_redirect = function(...) invisible(NULL),
    .env = env
  )
  testthat::local_mocked_bindings(
    julia_eval = function(name, ...) values[[name]],
    julia_call = function(...) invisible(NULL),
    .package = "JuliaCall", .env = env
  )
}

test_that("run_jl_step retrieves a single value and several values", {
  skip_if_not_installed("testthat", "3.2.0")
  mock_julia(values = list(result = 42, other = 7))
  script <- write_file("result = 42", ".jl")
  expect_identical(run_jl_step(script = script, retrieve = "result"), 42)
  expect_identical(
    run_jl_step(script = script, retrieve = c("result", "other")),
    list(result = 42, other = 7)
  )
})

test_that("run_jl_step object mode needs a post-script or retrieve", {
  skip_if_not_installed("testthat", "3.2.0")
  mock_julia()
  expect_error(
    run_jl_step(script = write_file("x = 1", ".jl")),
    "needs either a `post_script` or `retrieve`"
  )
})

test_that("run_jl_step file mode returns `files` and errors without paths", {
  skip_if_not_installed("testthat", "3.2.0")
  mock_julia()
  script <- write_file("x = 1", ".jl")
  res <- run_jl_step(script = script, output = "file", files = "jl_out.txt")
  expect_match(res[[1L]], "jl_out.txt", fixed = TRUE)
  expect_error(
    run_jl_step(script = script, output = "file"),
    "needs a `post_script` returning paths, or `files`"
  )
})

test_that("run_jl_step binds inputs into the post-script environment", {
  skip_if_not_installed("testthat", "3.2.0")
  mock_julia()
  out <- run_jl_step(
    script = write_file("x = 1", ".jl"),
    inputs = list(x = 21),
    post_script = write_file("x * 2", ".R")
  )
  expect_identical(out, 42)
})
