# Fast, structural tests for toolchain_check() and its internal building
# blocks. No live toolchains needed: presence checks against a nonexistent
# executable and error handling degrade gracefully by design.

test_that(".tp_check_row builds a one-row data.frame with the right columns", {
  row <- .tp_check_row("py", "some check", "ok", "detail text")
  expect_s3_class(row, "data.frame")
  expect_identical(nrow(row), 1L)
  expect_identical(names(row), c("toolchain", "check", "status", "detail"))
  expect_identical(row$toolchain, "py")
  expect_identical(row$status, "ok")
  expect_identical(row$detail, "detail text")
})

test_that(".tp_check_row defaults detail to an empty string", {
  row <- .tp_check_row("jl", "x", "warn")
  expect_identical(row$detail, "")
})

test_that(".tp_which_check reports a definitely-absent executable as a warning", {
  row <- .tp_which_check("py", "nonexistent-tool", "tp-definitely-not-a-real-executable-xyz",
    quiet = TRUE)
  expect_identical(row$status, "warn")
  expect_match(row$detail, "not found on PATH")
})

test_that(".tp_run_check turns an error from fn() into a fail row, not an abort", {
  row <- .tp_run_check("rs", "boom", quiet = TRUE, fn = function() stop("kaboom"))
  expect_identical(row$status, "fail")
  expect_match(row$detail, "kaboom")
})

test_that(".tp_run_check passes through a row fn() returns normally", {
  ok_row <- .tp_check_row("jl", "fine", "ok", "")
  row <- .tp_run_check("jl", "fine", quiet = TRUE, fn = function() ok_row)
  expect_identical(row, ok_row)
})

test_that(".tp_run_check reports quietly when quiet = TRUE", {
  expect_silent(.tp_run_check("py", "x", quiet = TRUE, fn = function() {
    .tp_check_row("py", "x", "ok", "")
  }))
})

test_that(".tp_require_callr returns NULL when callr is installed, a fail row otherwise", {
  skip_if_not_installed("callr")
  expect_null(.tp_require_callr("py", "x"))
})

test_that("toolchain_check() validates the toolchains argument", {
  expect_error(toolchain_check("nope"), "unrecognised value")
  expect_error(toolchain_check(c("py", "nope")), "unrecognised value")
  expect_error(toolchain_check(c("nope1", "nope2")), "nope1.*nope2")
})

test_that(".tp_juliaup_installed returns NULL when there is no juliaup depot", {
  withr::local_envvar(JULIA_DEPOT_PATH = withr::local_tempdir())
  expect_null(.tp_juliaup_installed())
})

test_that(".tp_report_versions returns NULL (nothing to add) when versions is NULL/empty", {
  expect_null(.tp_report_versions("py", "Python", quiet = TRUE, versions = NULL))
  expect_null(.tp_report_versions("py", "Python", quiet = TRUE,
    versions = data.frame(version = character(0), path = character(0), default = logical(0))))
})

test_that(".tp_report_versions builds a multi-line detail with (default) marked", {
  versions <- data.frame(
    version = c("3.14.6", "3.12.13"), path = c("/a/python", "/b/python"),
    default = c(FALSE, TRUE), stringsAsFactors = FALSE
  )
  row <- .tp_report_versions("py", "Python", quiet = TRUE, versions = versions)
  expect_identical(row$status, "ok")
  expect_match(row$detail, "Python 3.14.6, /a/python", fixed = TRUE)
  expect_match(row$detail, "Python 3.12.13 (default), /b/python", fixed = TRUE)
})

test_that(".tp_python_versions returns NULL when uv is not on PATH", {
  # Simulate "uv absent" by pointing PATH somewhere that has no uv executable.
  withr::local_envvar(PATH = tempdir())
  expect_null(.tp_python_versions("3.12.13", "/some/python"))
})

test_that(".tp_rust_toolchains returns NULL when rustup is not on PATH", {
  withr::local_envvar(PATH = tempdir())
  expect_null(.tp_rust_toolchains())
})

test_that("toolchain_check() is exported and its helpers are not", {
  expect_true("toolchain_check" %in% getNamespaceExports("tarpolyglot"))
  expect_false(".tp_check_row" %in% getNamespaceExports("tarpolyglot"))
})
