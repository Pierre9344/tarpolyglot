# Constructor behaviour for the C++ targets (Rcpp model). No C++ compiler
# needed: we only build the target object and inspect it.

cpp_file <- function() {
  f <- withr::local_tempfile(fileext = ".cpp", .local_envir = parent.frame())
  writeLines(c(
    "#include <Rcpp.h>",
    "// [[Rcpp::export]]",
    "double square(double x) { return x * x; }"
  ), f)
  f
}

cmd_of <- function(target) target$command$expr[[1]]

test_that("tar_target_cpp_raw returns a targets target", {
  t <- tar_target_cpp_raw("demo", cpp_file(), post_script = NULL)
  expect_s3_class(t, "tar_target")
  expect_identical(t$settings$name, "demo")
})

test_that("command calls run_cpp_step and wires inputs as symbols", {
  t <- tar_target_cpp_raw("demo", cpp_file(), inputs = c(x = "up1"))
  txt <- paste(deparse(cmd_of(t)), collapse = " ")
  expect_match(txt, "run_cpp_step")
  expect_true("up1" %in% all.vars(cmd_of(t)))
})

test_that("depends is carried into the command", {
  t <- tar_target_cpp_raw("demo", cpp_file(), depends = c("RcppArmadillo", "RcppEigen"))
  txt <- paste(deparse(cmd_of(t)), collapse = " ")
  expect_match(txt, "RcppArmadillo")
  expect_match(txt, "RcppEigen")
})

test_that("format defaults mirror the other languages", {
  expect_identical(tar_target_cpp_raw("a", cpp_file())$settings$format, "rds")
  expect_identical(
    tar_target_cpp_raw("b", cpp_file(), output = "file", files = "x")$settings$format,
    "file")
})

test_that("tar_target_cpp (NSE) deparses a bare name", {
  t <- tar_target_cpp(cpp_nse, cpp_file())
  expect_identical(t$settings$name, "cpp_nse")
})

test_that("name and script are validated", {
  expect_error(tar_target_cpp_raw(123, cpp_file()), "single non-empty string")
  expect_error(tar_target_cpp_raw("d", 123), "single non-empty")
})

test_that("tar_target_path() on script/post_script wires them as dependencies", {
  t <- tar_target_cpp_raw("e", tar_target_path("up_script"),
    post_script = tar_target_path("up_post"))
  vars <- all.vars(cmd_of(t))
  expect_true(all(c("up_script", "up_post") %in% vars))
})

test_that("a literal string script is unaffected (backward compatible, untracked)", {
  t <- tar_target_cpp_raw("f", cpp_file())
  txt <- paste(deparse(cmd_of(t)), collapse = " ")
  expect_match(txt, "script = \"")
})

arg_obj <- function(target, arg) eval(cmd_of(target)[[arg]])

test_that("tar_code() inline C++ script embeds source (single + multiline)", {
  t1 <- tar_target_cpp_raw("ci1",
    tar_code("// [[Rcpp::export]]\ndouble vsum(std::vector<double> x) { return 0; }"),
    inputs = c(x = "up"), post_script = "post.R")
  o1 <- arg_obj(t1, "script")
  expect_s3_class(o1, "tp_source")
  expect_identical(o1$code, "// [[Rcpp::export]]\ndouble vsum(std::vector<double> x) { return 0; }")

  t2 <- tar_target_cpp_raw("ci2", tar_code("
      // [[Rcpp::export]]
      double vsum(std::vector<double> x) {
          return 0;
      }
    "), inputs = c(x = "up"), post_script = "post.R")
  o2 <- arg_obj(t2, "script")
  expect_identical(
    o2$code,
    "// [[Rcpp::export]]\ndouble vsum(std::vector<double> x) {\n    return 0;\n}"
  )
})

test_that("tar_code({}) inline R post_script is an R-expression carrier", {
  t <- tar_target_cpp_raw("ci3", cpp_file(),
    post_script = tar_code({ vsum(x) }), inputs = c(x = "up"))
  expect_s3_class(arg_obj(t, "post_script"), "tp_expr")
})

test_that("an R { } block is rejected as the C++ script", {
  expect_error(
    tar_target_cpp_raw("ci4", tar_code({ 1 + 1 })),
    "cannot be an R"
  )
})
