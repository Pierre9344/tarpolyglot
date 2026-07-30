# Constructor behaviour for the Rust targets (extendr model). No Rust toolchain
# needed: we only build the target object and inspect it.

rs_file <- function() {
  f <- withr::local_tempfile(fileext = ".rs", .local_envir = parent.frame())
  writeLines("#[extendr]\nfn square(x: f64) -> f64 { x * x }", f)
  f
}

cmd_of <- function(target) target$command$expr[[1]]

test_that("tar_target_rs_raw returns a targets target", {
  t <- tar_target_rs_raw("demo", rs_file(), post_script = NULL)
  expect_s3_class(t, "tar_target")
  expect_identical(t$settings$name, "demo")
})

test_that("command calls run_rs_step and wires inputs as symbols", {
  t <- tar_target_rs_raw("demo", rs_file(), inputs = c(x = "up1"))
  txt <- paste(deparse(cmd_of(t)), collapse = " ")
  expect_match(txt, "run_rs_step")
  expect_true("up1" %in% all.vars(cmd_of(t)))
})

test_that("toolchain and dependencies are carried into the command", {
  t <- tar_target_rs_raw("demo", rs_file(),
    toolchain = "stable-x86_64-pc-windows-gnu",
    dependencies = list(serde_json = "1"))
  txt <- paste(deparse(cmd_of(t)), collapse = " ")
  expect_match(txt, "stable-x86_64-pc-windows-gnu")
  expect_match(txt, "serde_json")
})

test_that("format defaults mirror the other languages", {
  expect_identical(tar_target_rs_raw("a", rs_file())$settings$format, "rds")
  expect_identical(
    tar_target_rs_raw("b", rs_file(), output = "file", files = "x")$settings$format,
    "file")
})

test_that("tar_target_rs (NSE) deparses a bare name", {
  t <- tar_target_rs(rs_nse, rs_file())
  expect_identical(t$settings$name, "rs_nse")
})

test_that("name and script are validated", {
  expect_error(tar_target_rs_raw(123, rs_file()), "single non-empty string")
  expect_error(tar_target_rs_raw("d", 123), "single non-empty")
})

test_that("tar_target_path() on script/post_script wires them as dependencies", {
  t <- tar_target_rs_raw("e", tar_target_path("up_script"),
    post_script = tar_target_path("up_post"))
  vars <- all.vars(cmd_of(t))
  expect_true(all(c("up_script", "up_post") %in% vars))
})

test_that("a literal string script is unaffected (backward compatible, untracked)", {
  t <- tar_target_rs_raw("f", rs_file())
  txt <- paste(deparse(cmd_of(t)), collapse = " ")
  expect_match(txt, "script = \"")
})

arg_obj <- function(target, arg) eval(cmd_of(target)[[arg]])

test_that("tar_code() inline Rust script embeds source (single + multiline)", {
  t1 <- tar_target_rs_raw("ri1",
    tar_code("#[extendr] fn vsum(x: Vec<f64>) -> f64 { x.iter().sum() }"),
    inputs = c(x = "up"), post_script = "post.R")
  o1 <- arg_obj(t1, "script")
  expect_s3_class(o1, "tp_source")
  expect_identical(o1$code, "#[extendr] fn vsum(x: Vec<f64>) -> f64 { x.iter().sum() }")

  t2 <- tar_target_rs_raw("ri2", tar_code("
      #[extendr]
      fn vsum(x: Vec<f64>) -> f64 {
          x.iter().sum()
      }
    "), inputs = c(x = "up"), post_script = "post.R")
  o2 <- arg_obj(t2, "script")
  expect_identical(
    o2$code,
    "#[extendr]\nfn vsum(x: Vec<f64>) -> f64 {\n    x.iter().sum()\n}"
  )
})

test_that("tar_code({}) inline R post_script is an R-expression carrier", {
  t <- tar_target_rs_raw("ri3", rs_file(),
    post_script = tar_code({ vsum(x) }), inputs = c(x = "up"))
  expect_s3_class(arg_obj(t, "post_script"), "tp_expr")
})

test_that("an R { } block is rejected as the Rust script", {
  expect_error(
    tar_target_rs_raw("ri4", tar_code({ 1 + 1 })),
    "cannot be an R"
  )
})
