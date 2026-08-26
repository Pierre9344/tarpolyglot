# Orchestration tests for the compiled-language workers. rextendr::rust_source()
# and Rcpp::sourceCpp() are mocked, so what is exercised is the worker's own
# logic: reading the source, assembling the compiler arguments, the per-build
# RUSTUP_TOOLCHAIN handling, and the prebuilt-library guards. Real compilation
# is covered by test-integration-rust.R / test-integration-cpp.R.

write_file <- function(code, ext) {
  f <- withr::local_tempfile(fileext = ext, .local_envir = parent.frame())
  writeLines(code, f)
  f
}

# ---- Rust -----------------------------------------------------------------

test_that("run_rs_step compiles, binds inputs, and returns the post-script value", {
  skip_if_not_installed("testthat", "3.2.0")
  local_mocked_bindings(
    rust_source = function(code, env, quiet = TRUE, ...) {
      assign("go", function(v) v * 2, envir = env)
      invisible(NULL)
    },
    .package = "rextendr"
  )
  out <- run_rs_step(
    script = write_file("#[extendr] fn go(v: f64) -> f64 { 2.0 * v }", ".rs"),
    inputs = list(x = 21),
    post_script = write_file("go(x)", ".R")
  )
  expect_identical(out, 42)
})

test_that("run_rs_step forwards dependencies, features and profile to rust_source", {
  skip_if_not_installed("testthat", "3.2.0")
  seen <- NULL
  local_mocked_bindings(
    rust_source = function(code, env, quiet = TRUE, dependencies = NULL,
                           features = NULL, profile = NULL) {
      seen <<- list(code = code, dependencies = dependencies,
        features = features, profile = profile)
      assign("go", function(v) v, envir = env)
      invisible(NULL)
    },
    .package = "rextendr"
  )
  run_rs_step(
    script = write_file("SOURCE MARKER", ".rs"),
    post_script = write_file("1", ".R"),
    dependencies = list(serde = "1"),
    features = "std",
    profile = "release"
  )
  expect_match(seen$code, "SOURCE MARKER", fixed = TRUE)
  expect_identical(seen$dependencies, list(serde = "1"))
  expect_identical(seen$features, "std")
  expect_identical(seen$profile, "release")
})

test_that("run_rs_step sets RUSTUP_TOOLCHAIN for the build and restores it after", {
  skip_if_not_installed("testthat", "3.2.0")
  withr::local_envvar(RUSTUP_TOOLCHAIN = NA)
  during <- NA_character_
  local_mocked_bindings(
    rust_source = function(code, env, quiet = TRUE, ...) {
      during <<- Sys.getenv("RUSTUP_TOOLCHAIN", unset = NA_character_)
      assign("go", function(v) v, envir = env)
      invisible(NULL)
    },
    .package = "rextendr"
  )
  run_rs_step(
    script = write_file("x", ".rs"),
    post_script = write_file("1", ".R"),
    toolchain = "stable-x86_64-pc-windows-gnu"
  )
  expect_identical(during, "stable-x86_64-pc-windows-gnu")
  # Unset before the call, so unset again afterwards.
  expect_identical(Sys.getenv("RUSTUP_TOOLCHAIN", unset = NA_character_), NA_character_)
})

test_that("run_rs_step accepts inline source from tar_code()", {
  skip_if_not_installed("testthat", "3.2.0")
  seen <- NULL
  local_mocked_bindings(
    rust_source = function(code, env, quiet = TRUE, ...) {
      seen <<- code
      assign("go", function(v) v * 3, envir = env)
      invisible(NULL)
    },
    .package = "rextendr"
  )
  inline <- structure(list(code = "INLINE RUST"), class = c("tp_inline", "tp_source"))
  out <- run_rs_step(script = inline, inputs = list(x = 14),
    post_script = write_file("go(x)", ".R"))
  expect_identical(seen, "INLINE RUST")
  expect_identical(out, 42)
})

test_that("compile_rs_lib errors when no extendr library appears after the build", {
  skip_if_not_installed("testthat", "3.2.0")
  local_mocked_bindings(
    rust_source = function(...) invisible(NULL),
    .package = "rextendr"
  )
  expect_error(
    compile_rs_lib(script = write_file("x", ".rs")),
    "Could not locate the compiled extendr library"
  )
})

test_that("run_rs_step_prebuilt rejects anything that is not a compiled library", {
  expect_error(run_rs_step_prebuilt(lib = list()), "must be a compiled library object")
  expect_error(run_rs_step_prebuilt(lib = NULL), "must be a compiled library object")
})

# ---- C++ ------------------------------------------------------------------

test_that(".tp_cpp_source_code reads a file, passes inline source through, and adds depends", {
  f <- write_file("int y = 1;", ".cpp")
  expect_identical(.tp_cpp_source_code(f, NULL), "int y = 1;")

  inline <- structure(list(code = "int z = 2;"), class = c("tp_inline", "tp_source"))
  expect_identical(.tp_cpp_source_code(inline, NULL), "int z = 2;")

  withdep <- .tp_cpp_source_code(f, "RcppArmadillo")
  expect_match(withdep, "// [[Rcpp::depends(RcppArmadillo)]]", fixed = TRUE)
  expect_match(withdep, "int y = 1;", fixed = TRUE)
  # The attribute goes ahead of the user's own source, not instead of it.
  expect_lt(regexpr("Rcpp::depends", withdep, fixed = TRUE),
    regexpr("int y = 1;", withdep, fixed = TRUE))

  multi <- .tp_cpp_source_code(f, c("RcppArmadillo", "RcppEigen"))
  expect_match(multi, "RcppArmadillo", fixed = TRUE)
  expect_match(multi, "RcppEigen", fixed = TRUE)
})

test_that("run_cpp_step compiles, binds inputs, and returns the post-script value", {
  skip_if_not_installed("testthat", "3.2.0")
  local_mocked_bindings(
    sourceCpp = function(code, env, verbose = FALSE, ...) {
      assign("total", function(v) sum(v) * 2, envir = env)
      invisible(NULL)
    },
    .package = "Rcpp"
  )
  out <- run_cpp_step(
    script = write_file("// [[Rcpp::export]]\nint f() { return 1; }", ".cpp"),
    inputs = list(x = c(1, 2, 3, 4)),
    post_script = write_file("total(x)", ".R")
  )
  expect_identical(out, 20)
})

test_that("run_cpp_step forwards `depends` into the compiled source", {
  skip_if_not_installed("testthat", "3.2.0")
  seen <- NULL
  local_mocked_bindings(
    sourceCpp = function(code, env, verbose = FALSE, ...) {
      seen <<- code
      assign("total", function(v) 1, envir = env)
      invisible(NULL)
    },
    .package = "Rcpp"
  )
  run_cpp_step(
    script = write_file("BODY MARKER", ".cpp"),
    post_script = write_file("1", ".R"),
    depends = "RcppArmadillo"
  )
  expect_match(seen, "// [[Rcpp::depends(RcppArmadillo)]]", fixed = TRUE)
  expect_match(seen, "BODY MARKER", fixed = TRUE)
})

test_that("run_cpp_step_prebuilt rejects anything that is not a compiled library", {
  expect_error(run_cpp_step_prebuilt(lib = list()), "must be a compiled library object")
})

# compile_cpp_lib() reads back whatever sourceCpp() left in its build
# directory, so a faked build directory exercises the whole bundling path.
mock_sourcecpp_build <- function(dir, env = parent.frame()) {
  testthat::local_mocked_bindings(
    sourceCpp = function(code, env, verbose = FALSE, ...) {
      assign("f", function() 1, envir = env)
      list(buildDirectory = dir, functions = "f")
    },
    .package = "Rcpp", .env = env
  )
}

test_that("compile_cpp_lib bundles the library bytes and the generated wrapper", {
  skip_if_not_installed("testthat", "3.2.0")
  build <- withr::local_tempdir()
  writeBin(as.raw(c(1L, 2L, 3L)), file.path(build, "sourceCpp_1.dll"))
  writeLines("wrapper source line", file.path(build, "sourceCpp_1.cpp.R"))
  mock_sourcecpp_build(build)

  lib <- compile_cpp_lib(script = write_file("int f() { return 1; }", ".cpp"))
  expect_s3_class(lib, "tp_cpp_lib")
  expect_identical(lib$basename, "sourceCpp_1.dll")
  expect_identical(lib$bytes, as.raw(c(1L, 2L, 3L)))
  expect_identical(lib$wrapper_src, "wrapper source line")
  expect_identical(lib$objs_names, "f")
})

test_that("compile_cpp_lib insists on exactly one compiled library", {
  skip_if_not_installed("testthat", "3.2.0")
  empty <- withr::local_tempdir()
  mock_sourcecpp_build(empty)
  expect_error(
    compile_cpp_lib(script = write_file("x", ".cpp")),
    "Expected exactly one compiled library"
  )

  two <- withr::local_tempdir()
  writeBin(as.raw(1L), file.path(two, "sourceCpp_1.dll"))
  writeBin(as.raw(1L), file.path(two, "sourceCpp_2.dll"))
  mock_sourcecpp_build(two)
  expect_error(
    compile_cpp_lib(script = write_file("x", ".cpp")),
    "found 2"
  )
})

test_that("compile_cpp_lib insists on exactly one generated wrapper file", {
  skip_if_not_installed("testthat", "3.2.0")
  build <- withr::local_tempdir()
  writeBin(as.raw(1L), file.path(build, "sourceCpp_1.dll"))
  # library present, but no .cpp.R alongside it
  mock_sourcecpp_build(build)
  expect_error(
    compile_cpp_lib(script = write_file("x", ".cpp")),
    "Expected exactly one generated wrapper"
  )
})

test_that(".tp_with_cpp_build_env extends PATH for the build and restores it after", {
  old <- Sys.getenv("PATH")
  restore <- .tp_with_cpp_build_env()
  expect_true(nchar(Sys.getenv("PATH")) >= nchar(old))
  restore()
  expect_identical(Sys.getenv("PATH"), old)
})
