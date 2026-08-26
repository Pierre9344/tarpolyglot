# Live C++ round-trip via Rcpp. Gated behind an env var (see the Python
# file); also needs a C++ compiler reachable by R (Rtools on Windows).
# run_cpp_step sets up PATH for the build itself.
#   Sys.setenv(TARPOLYGLOT_INTEGRATION = "true"); devtools::test()

skip_if(
  Sys.getenv("TARPOLYGLOT_INTEGRATION") != "true",
  "set TARPOLYGLOT_INTEGRATION=true to run live C++ tests"
)
skip_if_not_installed("Rcpp")

test_that("run_cpp_step compiles // [[Rcpp::export]] fns and returns via post-script", {
  script <- withr::local_tempfile(fileext = ".cpp")
  writeLines(c(
    "#include <Rcpp.h>",
    "// [[Rcpp::export]]",
    "double vsum(std::vector<double> x) { double s = 0; for (double v : x) s += v; return s; }"
  ), script)
  post <- withr::local_tempfile(fileext = ".R")
  writeLines("list(sum = vsum(x), n = length(x))", post)

  res <- run_cpp_step(script, post_script = post, inputs = list(x = c(1, 2, 3, 4)))
  expect_equal(res$sum, 10)
  expect_equal(res$n, 4)
})

test_that("multiple // [[Rcpp::export]] functions in one script are all exposed", {
  script <- withr::local_tempfile(fileext = ".cpp")
  writeLines(c(
    "#include <Rcpp.h>",
    "// [[Rcpp::export]]",
    "double inc(double x) { return x + 1.0; }",
    "// [[Rcpp::export]]",
    "double tentimes(double x) { return x * 10.0; }"
  ), script)
  lib <- compile_cpp_lib(script)
  expect_true(all(c("inc", "tentimes") %in% lib$objs_names))
  post <- withr::local_tempfile(fileext = ".R")
  writeLines("c(inc(x), tentimes(x))", post)
  expect_equal(run_cpp_step_prebuilt(lib, post_script = post, inputs = list(x = 5)),
    c(6, 50))
})

test_that("depends = 'RcppArmadillo' compiles and links successfully", {
  skip_if_not_installed("RcppArmadillo")
  script <- withr::local_tempfile(fileext = ".cpp")
  writeLines(c(
    "#include <RcppArmadillo.h>",
    "// [[Rcpp::export]]",
    "double arma_sum(arma::vec x) { return arma::sum(x); }"
  ), script)
  post <- withr::local_tempfile(fileext = ".R")
  writeLines("arma_sum(x)", post)
  res <- run_cpp_step(script, post_script = post, inputs = list(x = c(1, 2, 3)),
    depends = "RcppArmadillo")
  expect_equal(res, 6)
})

test_that("two libraries sharing the sourceCpp module name do not collide", {
  skip_if_not_installed("callr")
  # Compile in fresh processes so both get the per-session module name
  # sourceCpp_<N> reset (the collision case). One process then reloads both
  # in turn, as a reused crew worker would.
  compile_fresh <- function(cpp) {
    script <- tempfile(fileext = ".cpp")
    writeLines(cpp, script)
    on.exit(unlink(script), add = TRUE)
    callr::r(function(s) tarpolyglot::compile_cpp_lib(s), args = list(script))
  }
  libA <- compile_fresh(c(
    "#include <Rcpp.h>", "// [[Rcpp::export]]",
    "double f(double x) { return x + 1.0; }"
  ))
  libB <- compile_fresh(c(
    "#include <Rcpp.h>", "// [[Rcpp::export]]",
    "double f(double x) { return x + 100.0; }"
  ))
  expect_identical(libA$basename, libB$basename)  # same module name => collision risk

  post <- withr::local_tempfile(fileext = ".R")
  writeLines("f(x)", post)
  # Hot-swap must give each library its own behaviour, in both directions.
  expect_equal(run_cpp_step_prebuilt(libA, post_script = post, inputs = list(x = 5)), 6)
  expect_equal(run_cpp_step_prebuilt(libB, post_script = post, inputs = list(x = 5)), 105)
  expect_equal(run_cpp_step_prebuilt(libA, post_script = post, inputs = list(x = 5)), 6)
})

test_that("compile_cpp_lib() builds a reusable bundle that run_cpp_step_prebuilt reloads", {
  script <- withr::local_tempfile(fileext = ".cpp")
  writeLines(c(
    "#include <Rcpp.h>",
    "// [[Rcpp::export]]",
    "double square(double x) { return x * x; }"
  ), script)
  post <- withr::local_tempfile(fileext = ".R")
  writeLines("square(x)", post)

  # Compile once.
  lib <- compile_cpp_lib(script)
  expect_s3_class(lib, "tp_cpp_lib")
  expect_true(is.raw(lib$bytes) && length(lib$bytes) > 0)
  expect_true("square" %in% lib$objs_names)

  # Reuse it several times with different inputs (this is what each branch
  # does), with no further compilation.
  expect_equal(run_cpp_step_prebuilt(lib, post_script = post, inputs = list(x = 10)), 100)
  expect_equal(run_cpp_step_prebuilt(lib, post_script = post, inputs = list(x = 20)), 400)
  expect_equal(run_cpp_step_prebuilt(lib, post_script = post, inputs = list(x = 30)), 900)
})

test_that("compile_cpp_lib() bundle reloads correctly in a genuinely different process", {
  skip_if_not_installed("callr")
  script <- withr::local_tempfile(fileext = ".cpp")
  writeLines(c(
    "#include <Rcpp.h>",
    "// [[Rcpp::export]]",
    "double cube(double x) { return x * x * x; }"
  ), script)
  lib <- compile_cpp_lib(script)

  post <- withr::local_tempfile(fileext = ".R")
  writeLines("cube(x)", post)
  # Reload in a fresh R process: this is the scenario compile_cpp_lib()'s
  # docs describe -- a raw-pointer-captured wrapper from the compiling
  # process would be invalid here, so this specifically exercises the
  # wrapper-source re-evaluation path, not just in-process reuse.
  res <- callr::r(
    function(lib, post_script, x) {
      tarpolyglot::run_cpp_step_prebuilt(lib, post_script = post_script, inputs = list(x = x))
    },
    args = list(lib = lib, post_script = post, x = 4)
  )
  expect_equal(res, 64)
})

test_that("everything together: extension package + R-callback + compile-once branching + cross-step reuse, all in one script", {
  # Point 12 of the roadmap's C++ item: a single compiled function using
  # RcppArmadillo (extension package) AND an Rcpp::Function R-callback,
  # compiled once (compile_cpp_lib(), what tarpolyglot_map() does under the
  # hood), reused across several simulated branches (run_cpp_step_prebuilt()
  # called repeatedly, one of them in a genuinely fresh process to prove the
  # cross-process reload story holds even with these two features combined),
  # then reused again in a wholly separate "downstream step" call with
  # different inputs -- the same guarantee point 5 proved for a plain script,
  # now proved for one that also uses an extension package and a callback.
  skip_if_not_installed("RcppArmadillo")
  skip_if_not_installed("callr")

  script <- withr::local_tempfile(fileext = ".cpp")
  writeLines(c(
    "// [[Rcpp::depends(RcppArmadillo)]]",
    "#include <RcppArmadillo.h>",
    "// [[Rcpp::export]]",
    "double combo_stat(arma::vec x, Rcpp::Function agg) {",
    "  double s = arma::sum(x);",
    "  double m = arma::mean(x);",
    "  Rcpp::NumericVector agg_result = agg(Rcpp::wrap(x));",
    "  double agg_val = agg_result[0];",
    "  return s + m + agg_val;",
    "}"
  ), script)
  post <- withr::local_tempfile(fileext = ".R")
  writeLines("combo_stat(x, agg)", post)

  lib <- compile_cpp_lib(script)
  expect_s3_class(lib, "tp_cpp_lib")
  expect_true("combo_stat" %in% lib$objs_names)

  double_mean <- function(v) mean(v) * 2

  # "Branches": same library, different x, same R-callback each time.
  # x = c(1,2,3): sum=6, mean=2, agg=mean*2=4 -> 12
  expect_equal(
    run_cpp_step_prebuilt(lib, post_script = post, inputs = list(x = c(1, 2, 3), agg = double_mean)),
    12
  )
  # x = c(4,5,6): sum=15, mean=5, agg=10 -> 30
  expect_equal(
    run_cpp_step_prebuilt(lib, post_script = post, inputs = list(x = c(4, 5, 6), agg = double_mean)),
    30
  )

  # One "branch" reloaded in a genuinely fresh process -- the raw-pointer
  # wrapper concern applies identically whether or not the script also uses
  # an extension package or a callback.
  # x = c(7,8,9): sum=24, mean=8, agg=16 -> 48
  res_fresh <- callr::r(
    function(lib, post_script, x, agg) {
      tarpolyglot::run_cpp_step_prebuilt(lib, post_script = post_script, inputs = list(x = x, agg = agg))
    },
    args = list(lib = lib, post_script = post, x = c(7, 8, 9), agg = double_mean)
  )
  expect_equal(res_fresh, 48)

  # Reuse in a wholly separate "downstream step", different inputs and a
  # different R-callback (sum instead of double_mean) -- not a branch of
  # anything, mirroring the plain-script cross-step-reuse test above.
  # x = c(100,200,300): sum=600, mean=200, agg=sum=600 -> 1400
  expect_equal(
    run_cpp_step_prebuilt(lib, post_script = post,
      inputs = list(x = c(100, 200, 300), agg = sum)),
    1400
  )
})
