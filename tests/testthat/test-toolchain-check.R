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

test_that(".tp_cpp_compiler_cmd returns R's own configured CXX compiler", {
  cmd <- .tp_cpp_compiler_cmd()
  expect_true(is.character(cmd) && length(cmd) == 1L)
  expect_false(is.na(cmd))
  expect_true(nzchar(cmd))
})

test_that("toolchain_check('cpp') checks only Rcpp, not the extension packages", {
  res <- toolchain_check("cpp", deep = FALSE, quiet = TRUE)
  expect_true("Rcpp" %in% res$check)
  expect_false(any(c("RcppArmadillo", "RcppEigen", "RcppParallel") %in% res$check))
})

test_that(".tp_check_report emits one alert per status and returns the row invisibly", {
  for (st in c("ok", "warn", "fail", "info")) {
    row <- .tp_check_row("py", "a check", st, "some detail")
    out <- suppressMessages(.tp_check_report(row, quiet = FALSE))
    expect_identical(out$status, st)
  }
  # A row with no detail takes the bare-check-name branch of the message.
  bare <- .tp_check_row("py", "no detail", "ok")
  expect_identical(suppressMessages(.tp_check_report(bare, quiet = FALSE))$check, "no detail")
})

test_that(".tp_report_versions renders one version as a line and several as a list", {
  one <- data.frame(version = "3.12.13", path = "/a/python", default = TRUE,
    stringsAsFactors = FALSE)
  row <- suppressMessages(.tp_report_versions("py", "Python", quiet = FALSE, versions = one))
  expect_identical(row$status, "ok")
  expect_match(row$detail, "(default)", fixed = TRUE)

  many <- data.frame(version = c("3.12.13", "3.14.6"), path = c("/a", "/b"),
    default = c(TRUE, FALSE), stringsAsFactors = FALSE)
  row2 <- suppressMessages(.tp_report_versions("py", "Python", quiet = FALSE, versions = many))
  expect_identical(row2$status, "ok")
  expect_match(row2$detail, "\n")
})

test_that(".tp_which_check reports a present executable with its path", {
  # R itself is the one executable guaranteed to exist wherever these run.
  skip_if(!nzchar(Sys.which("R")), "R is not on PATH")
  row <- .tp_which_check("rs", "R", "R", quiet = TRUE)
  expect_identical(row$status, "ok")
  expect_true(nzchar(row$detail))
})

test_that(".tp_juliaup_installed enumerates depot builds and marks the resolved default", {
  depot <- withr::local_tempdir()
  for (b in c("julia-1.10.11+0.x64", "julia-1.11.2+0.x64")) {
    dir.create(file.path(depot, "juliaup", b, "bin"), recursive = TRUE)
  }
  withr::local_envvar(JULIA_DEPOT_PATH = depot)

  v <- .tp_juliaup_installed()
  expect_identical(nrow(v), 2L)
  expect_setequal(v$version, c("1.10.11", "1.11.2"))
  expect_false(any(v$default))

  v2 <- .tp_juliaup_installed("1.11.2")
  expect_true(v2$default[v2$version == "1.11.2"])
  expect_false(v2$default[v2$version == "1.10.11"])
})

test_that(".tp_check_rs degrades to warn/fail rows when no Rust toolchain is on PATH", {
  # An empty PATH makes rustup and cargo unreachable, which is the branch a
  # machine without Rust takes. deep = FALSE keeps this off the compiler.
  withr::local_envvar(PATH = withr::local_tempdir())
  res <- suppressWarnings(.tp_check_rs(deep = FALSE, quiet = TRUE))

  expect_s3_class(res, "data.frame")
  expect_true(all(c("rustup", "cargo") %in% res$check))
  expect_identical(res$status[res$check == "rustup"], "warn")
  expect_identical(res$status[res$check == "cargo"], "warn")
  expect_true(all(res$status %in% c("ok", "warn", "fail")))
  # No compile row without deep = TRUE.
  expect_false("Compile reachability (fresh worker)" %in% res$check)
})

# The fresh-worker checks all delegate to callr::r(). Mocking it lets the
# row-building logic around each call be tested without a live Python, Julia,
# Rust or C++ toolchain; the real subprocess calls are covered by the
# test-integration-*.R files.

test_that(".tp_check_py reports the interpreter the fresh worker resolved", {
  skip_if_not_installed("testthat", "3.2.0")
  local_mocked_bindings(
    r = function(...) {
      list(python = "/tp/fake/python", version = "3.12",
        full_version = "3.12.13", venv_ok = TRUE)
    },
    .package = "callr"
  )
  res <- .tp_check_py(deep = FALSE, quiet = TRUE)
  row <- res[res$check == "Python interpreter (fresh worker)", ]
  expect_identical(row$status, "ok")
  expect_match(row$detail, "/tp/fake/python", fixed = TRUE)
  expect_match(row$detail, "venv module available", fixed = TRUE)
})

test_that(".tp_check_py flags an interpreter whose venv module is missing", {
  skip_if_not_installed("testthat", "3.2.0")
  local_mocked_bindings(
    r = function(...) {
      list(python = "/tp/fake/python", version = "3.12",
        full_version = "3.12.13", venv_ok = FALSE)
    },
    .package = "callr"
  )
  res <- .tp_check_py(deep = FALSE, quiet = TRUE)
  row <- res[res$check == "Python interpreter (fresh worker)", ]
  expect_match(row$detail, "venv module NOT available", fixed = TRUE)
})

test_that(".tp_check_py turns a failing fresh-worker call into a fail row", {
  skip_if_not_installed("testthat", "3.2.0")
  local_mocked_bindings(
    r = function(...) stop("no python here"),
    .package = "callr"
  )
  res <- .tp_check_py(deep = FALSE, quiet = TRUE)
  row <- res[res$check == "Python interpreter (fresh worker)", ]
  expect_identical(row$status, "fail")
  expect_match(row$detail, "no python here")
})

test_that(".tp_check_jl reports Julia discovery and a working Pkg environment", {
  skip_if_not_installed("testthat", "3.2.0")
  calls <- 0L
  local_mocked_bindings(
    r = function(...) {
      calls <<- calls + 1L
      if (calls == 1L) {
        list(version = "1.11.2", bindir = "/tp/fake/julia/bin")
      } else {
        list(pkg_version = "1.11.0", active_project = "/tp/proj/Project.toml")
      }
    },
    .package = "callr"
  )
  res <- .tp_check_jl(deep = FALSE, quiet = TRUE)

  disc <- res[res$check == "Julia interpreter (fresh worker)", ]
  expect_identical(disc$status, "ok")
  expect_match(disc$detail, "Julia 1.11.2", fixed = TRUE)

  pkg <- res[res$check == "Pkg (environment manager, fresh worker)", ]
  expect_identical(pkg$status, "ok")
  expect_match(pkg$detail, "Pkg.activate() into a fresh project succeeded", fixed = TRUE)
})

test_that(".tp_check_jl fails the Pkg check when no project is reported active", {
  skip_if_not_installed("testthat", "3.2.0")
  calls <- 0L
  local_mocked_bindings(
    r = function(...) {
      calls <<- calls + 1L
      if (calls == 1L) {
        list(version = "1.11.2", bindir = "/tp/fake/julia/bin")
      } else {
        list(pkg_version = "1.11.0", active_project = "")
      }
    },
    .package = "callr"
  )
  res <- .tp_check_jl(deep = FALSE, quiet = TRUE)
  pkg <- res[res$check == "Pkg (environment manager, fresh worker)", ]
  expect_identical(pkg$status, "fail")
  expect_match(pkg$detail, "did not report an active project", fixed = TRUE)
})

test_that(".tp_check_py reports every missing environment manager as a warning", {
  skip_if_not_installed("testthat", "3.2.0")
  # No tools on PATH is the shape of a bare machine: each presence check should
  # degrade to a warning rather than aborting the whole diagnostic.
  withr::local_envvar(PATH = withr::local_tempdir())
  local_mocked_bindings(r = function(...) stop("no python here"), .package = "callr")

  res <- suppressWarnings(.tp_check_py(deep = FALSE, quiet = TRUE))
  for (tool in c("uv", "poetry", "conda")) {
    expect_identical(res$status[res$check == tool], "warn", label = tool)
  }
  expect_identical(res$status[res$check == "Python interpreter (fresh worker)"], "fail")
})

test_that(".tp_check_jl warns when juliaup is not on PATH", {
  skip_if_not_installed("testthat", "3.2.0")
  withr::local_envvar(
    PATH = withr::local_tempdir(),
    JULIA_DEPOT_PATH = withr::local_tempdir()
  )
  local_mocked_bindings(r = function(...) stop("no julia here"), .package = "callr")

  res <- suppressWarnings(.tp_check_jl(deep = FALSE, quiet = TRUE))
  juliaup <- res[res$check == "juliaup", ]
  expect_identical(juliaup$status, "warn")
  expect_match(juliaup$detail, "not found on PATH", fixed = TRUE)
  # A failing fresh-worker call must still produce rows, not abort.
  expect_identical(res$status[res$check == "Julia interpreter (fresh worker)"], "fail")
})

test_that(".tp_check_jl lists installed juliaup versions when juliaup is present", {
  skip_if_not_installed("testthat", "3.2.0")
  skip_if(!nzchar(Sys.which("juliaup")), "juliaup not installed")
  depot <- withr::local_tempdir()
  dir.create(file.path(depot, "juliaup", "julia-1.10.11+0.x64", "bin"), recursive = TRUE)
  withr::local_envvar(JULIA_DEPOT_PATH = depot)
  local_mocked_bindings(r = function(...) stop("skip the worker"), .package = "callr")

  res <- suppressWarnings(.tp_check_jl(deep = FALSE, quiet = TRUE))
  juliaup <- res[res$check == "juliaup", ]
  expect_identical(juliaup$status, "ok")
  expect_match(juliaup$detail, "installed: 1.10.11", fixed = TRUE)
})

test_that("the deep compile check passes when the fresh worker returns the expected value", {
  skip_if_not_installed("testthat", "3.2.0")
  local_mocked_bindings(r = function(...) 2, .package = "callr")
  for (fn in list(.tp_check_rs, .tp_check_cpp)) {
    res <- suppressWarnings(fn(deep = TRUE, quiet = TRUE))
    row <- res[res$check == "Compile reachability (fresh worker)", ]
    expect_identical(row$status, "ok")
    expect_match(row$detail, "compiled and ran successfully")
  }
})

test_that("the deep compile check fails on an unexpected value from the fresh worker", {
  skip_if_not_installed("testthat", "3.2.0")
  local_mocked_bindings(r = function(...) 99, .package = "callr")
  for (fn in list(.tp_check_rs, .tp_check_cpp)) {
    res <- suppressWarnings(fn(deep = TRUE, quiet = TRUE))
    row <- res[res$check == "Compile reachability (fresh worker)", ]
    expect_identical(row$status, "fail")
    expect_match(row$detail, "unexpected result: 99", fixed = TRUE)
  }
})

test_that("toolchain_check('rs') reports its summary and returns rows invisibly", {
  withr::local_envvar(PATH = withr::local_tempdir())
  res <- suppressWarnings(suppressMessages(
    toolchain_check("rs", deep = FALSE, quiet = FALSE)
  ))
  expect_s3_class(res, "data.frame")
  expect_true(nrow(res) > 0L)
  expect_identical(unique(res$toolchain), "rs")
  expect_identical(names(res), c("toolchain", "check", "status", "detail"))
  # toolchain_check() resets row names, so they are the default 1..n sequence.
  expect_identical(rownames(res), as.character(seq_len(nrow(res))))
})
