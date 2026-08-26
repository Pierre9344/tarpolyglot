# The RStudio addin bindings are thin wrappers around toolchain_check().
# toolchain_check() is mocked here so the wrappers can be checked for the
# argument they forward without running any real toolchain diagnostics.

test_that("the addin wrappers delegate to toolchain_check() with the right toolchain", {
  skip_if_not_installed("testthat", "3.2.0")

  seen <- list()
  local_mocked_bindings(
    toolchain_check = function(...) {
      seen[[length(seen) + 1L]] <<- list(...)
      invisible(NULL)
    }
  )

  expect_null(rstudio_addin_toolchain_check_all())
  expect_null(rstudio_addin_toolchain_check_py())
  expect_null(rstudio_addin_toolchain_check_jl())
  expect_null(rstudio_addin_toolchain_check_rs())
  expect_null(rstudio_addin_toolchain_check_cpp())

  expect_length(seen, 5L)
  expect_length(seen[[1L]], 0L)             # "all" passes no toolchain argument
  expect_identical(seen[[2L]][[1L]], "py")
  expect_identical(seen[[3L]][[1L]], "jl")
  expect_identical(seen[[4L]][[1L]], "rs")
  expect_identical(seen[[5L]][[1L]], "cpp")
})

test_that("every binding declared in addins.dcf exists in the namespace", {
  f <- system.file("rstudio", "addins.dcf", package = "tarpolyglot")
  skip_if(!nzchar(f), "addins.dcf not found")
  bindings <- read.dcf(f)[, "Binding"]
  expect_true(length(bindings) > 0L)
  for (b in bindings) {
    expect_true(exists(b, envir = asNamespace("tarpolyglot"), inherits = FALSE))
  }
})
