# Live C++ round-trip for inline code (tar_code()) via Rcpp. Gated like the
# other integration tests; also needs a C++ compiler reachable by R.

skip_if(
  Sys.getenv("TARPOLYGLOT_INTEGRATION") != "true",
  "set TARPOLYGLOT_INTEGRATION=true to run live C++ tests"
)
skip_if_not_installed("Rcpp")

test_that("inline C++ (single line) round-trips", {
  res <- run_cpp_step(
    script = tar_code("#include <Rcpp.h>\n// [[Rcpp::export]]\ndouble vsum(std::vector<double> x) { double s = 0; for (double v : x) s += v; return s; }"),
    post_script = tar_code({ vsum(x) }),
    inputs = list(x = c(1, 2, 3, 4))
  )
  expect_equal(res, 10)
})

test_that("inline C++ (multiline) round-trips", {
  res <- run_cpp_step(
    script = tar_code("
      #include <Rcpp.h>
      // [[Rcpp::export]]
      double vsum(std::vector<double> x) {
          double s = 0;
          for (double v : x) s += v;
          return s;
      }
    "),
    post_script = tar_code({ vsum(x) }),
    inputs = list(x = c(1, 2, 3, 4))
  )
  expect_equal(res, 10)
})
