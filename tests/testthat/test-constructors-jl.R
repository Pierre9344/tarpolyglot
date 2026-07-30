# Constructor behaviour for the Julia targets. No Julia needed.

jl_file <- function() {
  f <- withr::local_tempfile(fileext = ".jl", .local_envir = parent.frame())
  writeLines("result = 1", f)
  f
}

cmd_of <- function(target) target$command$expr[[1]]

test_that("tar_target_jl_raw returns a targets target", {
  t <- tar_target_jl_raw("demo", jl_file(), retrieve = "result")
  expect_s3_class(t, "tar_target")
  expect_identical(t$settings$name, "demo")
})

test_that("command calls run_jl_step and wires inputs as symbols", {
  t <- tar_target_jl_raw("demo", jl_file(),
    inputs = c(x = "up1"), retrieve = "result")
  txt <- paste(deparse(cmd_of(t)), collapse = " ")
  expect_match(txt, "run_jl_step")
  expect_true("up1" %in% all.vars(cmd_of(t)))
})

test_that("julia_project / julia_packages are forwarded into the command", {
  t <- tar_target_jl_raw("demo", jl_file(), retrieve = "result",
    julia_project = "env", julia_packages = c("Statistics", "LinearAlgebra"))
  txt <- paste(deparse(cmd_of(t)), collapse = " ")
  expect_match(txt, "julia_project")
  expect_match(txt, "Statistics")
})

test_that("format defaults mirror the Python side", {
  expect_identical(
    tar_target_jl_raw("a", jl_file(), retrieve = "result")$settings$format, "rds")
  expect_identical(
    tar_target_jl_raw("b", jl_file(), output = "file", files = "x")$settings$format,
    "file")
})

test_that("tar_target_jl (NSE) deparses a bare name", {
  t <- tar_target_jl(jl_nse, jl_file(), retrieve = "result")
  expect_identical(t$settings$name, "jl_nse")
})

test_that("name and script are validated", {
  expect_error(tar_target_jl_raw(123, jl_file()), "single non-empty string")
  expect_error(tar_target_jl_raw("d", 123), "single non-empty")
})

test_that("tar_target_path() on script/pre_script/post_script wires them as dependencies", {
  t <- tar_target_jl_raw("w", tar_target_path("up_script"),
    pre_script = tar_target_path("up_pre"),
    post_script = tar_target_path("up_post"),
    retrieve = "result")
  vars <- all.vars(cmd_of(t))
  expect_true(all(c("up_script", "up_pre", "up_post") %in% vars))
})

test_that("a literal string script is unaffected (backward compatible, untracked)", {
  t <- tar_target_jl_raw("x", jl_file(), retrieve = "result")
  txt <- paste(deparse(cmd_of(t)), collapse = " ")
  expect_match(txt, "script = \"")
})

test_that("julia_version is carried into the command", {
  t <- tar_target_jl_raw("v", jl_file(), retrieve = "result",
    julia_version = "1.11")
  txt <- paste(deparse(cmd_of(t)), collapse = " ")
  expect_match(txt, 'julia_version = "1.11"')
})

arg_obj <- function(target, arg) eval(cmd_of(target)[[arg]])

test_that("tar_code() inline Julia script embeds source (single + multiline)", {
  t1 <- tar_target_jl_raw("ji1", tar_code("result = sum(x)"),
    inputs = c(x = "up"), retrieve = "result")
  o1 <- arg_obj(t1, "script")
  expect_s3_class(o1, "tp_source")
  expect_identical(o1$code, "result = sum(x)")

  t2 <- tar_target_jl_raw("ji2", tar_code("
      function f(v)
          sum(v)
      end
      result = f(x)
    "), inputs = c(x = "up"), retrieve = "result")
  o2 <- arg_obj(t2, "script")
  expect_identical(o2$code, "function f(v)\n    sum(v)\nend\nresult = f(x)")
})

test_that("tar_code({}) inline R pre/post are R-expression carriers", {
  t <- tar_target_jl_raw("ji3", jl_file(),
    pre_script = tar_code({ to_jl <- list(x = x) }),
    post_script = tar_code({ jl_get("result") }),
    inputs = c(x = "up"))
  expect_s3_class(arg_obj(t, "pre_script"), "tp_expr")
  expect_s3_class(arg_obj(t, "post_script"), "tp_expr")
})

test_that("an R { } block is rejected as the Julia script", {
  expect_error(
    tar_target_jl_raw("ji4", tar_code({ 1 + 1 }), retrieve = "result"),
    "cannot be an R"
  )
})
