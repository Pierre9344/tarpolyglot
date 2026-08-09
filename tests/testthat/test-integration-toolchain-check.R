# Live toolchain_check() smoke tests: actually probe each real toolchain via
# a fresh worker. Gated behind an env var (see test-integration-python.R).
#   Sys.setenv(TARPOLYGLOT_INTEGRATION = "true"); devtools::test()

skip_if(
  Sys.getenv("TARPOLYGLOT_INTEGRATION") != "true",
  "set TARPOLYGLOT_INTEGRATION=true to run live toolchain_check() tests"
)
skip_if_not_installed("callr")

test_that("toolchain_check('py') finds a reachable Python in a fresh worker", {
  skip_if_not_installed("reticulate")
  skip_if_not(reticulate::py_available(initialize = TRUE), "no Python available")

  res <- toolchain_check("py", quiet = TRUE)
  expect_setequal(res$toolchain, "py")
  interp <- res[res$check == "Python interpreter (fresh worker)", ]
  expect_identical(nrow(interp), 1L)
  expect_identical(interp$status, "ok")
  expect_match(interp$detail, "Python")
})

test_that("toolchain_check('jl') finds a reachable Julia in a fresh worker", {
  skip_if_not_installed("JuliaCall")
  julia_ok <- tryCatch({
    JuliaCall::julia_setup(installJulia = FALSE, verbose = FALSE)
    TRUE
  }, error = function(e) FALSE)
  skip_if_not(julia_ok, "no Julia available")

  res <- toolchain_check("jl", quiet = TRUE)
  expect_setequal(res$toolchain, "jl")
  disc <- res[res$check == "Julia interpreter (fresh worker)", ]
  expect_identical(nrow(disc), 1L)
  expect_identical(disc$status, "ok")
  expect_match(disc$detail, "Julia")
})

test_that("toolchain_check('jl') confirms Pkg.activate() works in a fresh worker", {
  skip_if_not_installed("JuliaCall")
  julia_ok <- tryCatch({
    JuliaCall::julia_setup(installJulia = FALSE, verbose = FALSE)
    TRUE
  }, error = function(e) FALSE)
  skip_if_not(julia_ok, "no Julia available")

  res <- toolchain_check("jl", quiet = TRUE)
  pkg_row <- res[res$check == "Pkg (environment manager, fresh worker)", ]
  expect_identical(nrow(pkg_row), 1L)
  expect_identical(pkg_row$status, "ok")
  expect_match(pkg_row$detail, "Pkg\\.activate")
})

test_that("toolchain_check('rs') compiles successfully in a fresh worker (deep = TRUE)", {
  skip_if_not_installed("rextendr")
  cargo_ok <- nzchar(Sys.which("cargo")) ||
    file.exists(file.path(Sys.getenv("USERPROFILE", Sys.getenv("HOME")),
      ".cargo", "bin", "cargo.exe"))
  skip_if_not(cargo_ok, "cargo not available")

  res <- toolchain_check("rs", deep = TRUE, quiet = TRUE)
  expect_setequal(res$toolchain, "rs")
  compile <- res[res$check == "Compile reachability (fresh worker)", ]
  expect_identical(nrow(compile), 1L)
  expect_identical(compile$status, "ok")
})

test_that("toolchain_check() with all three toolchains returns one row set per language", {
  res <- toolchain_check(quiet = TRUE, deep = FALSE)
  expect_setequal(unique(res$toolchain), c("py", "jl", "rs"))
  expect_true(all(res$status %in% c("ok", "warn", "fail")))
})

# --- multi-version discovery: at most one entry per language is marked
# (default), and when a version manager is present, at least one version is
# listed. These skip cleanly (no row at all) when the manager is absent.

test_that("at most one Python version is marked (default)", {
  res <- toolchain_check("py", quiet = TRUE, deep = FALSE)
  row <- res[res$check == "Python versions", ]
  skip_if(nrow(row) == 0L, "uv not available; nothing to enumerate")
  n_default <- lengths(regmatches(row$detail, gregexpr("\\(default\\)", row$detail)))
  expect_lte(n_default, 1L)
})

test_that("at most one Julia version is marked (default)", {
  res <- toolchain_check("jl", quiet = TRUE, deep = FALSE)
  row <- res[res$check == "Julia versions", ]
  skip_if(nrow(row) == 0L, "juliaup not available; nothing to enumerate")
  n_default <- lengths(regmatches(row$detail, gregexpr("\\(default\\)", row$detail)))
  expect_lte(n_default, 1L)
})

test_that("rustup marks exactly its default toolchain (default) in the Rust versions list", {
  res <- toolchain_check("rs", quiet = TRUE, deep = FALSE)
  row <- res[res$check == "Rust toolchain versions", ]
  skip_if(nrow(row) == 0L, "rustup not available; nothing to enumerate")
  # rustup itself marks its default inline (no cross-referencing needed, see
  # .tp_rust_toolchains()), so this one IS reliably present when rustup has a
  # default toolchain configured at all.
  expect_match(row$detail, "\\(default\\)")
})
