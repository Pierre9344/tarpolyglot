# Constructor behaviour for the Python targets. No Python needed: we only build
# the target object and inspect it.

py_file <- function() {
  f <- withr::local_tempfile(fileext = ".py", .local_envir = parent.frame())
  writeLines("result = 1", f)
  f
}

cmd_of <- function(target) target$command$expr[[1]]

test_that("tar_target_py_raw returns a targets target", {
  t <- tar_target_py_raw("demo", py_file(), retrieve = "result")
  expect_s3_class(t, "tar_target")
  expect_s3_class(t, "tar_stem")
  expect_identical(t$settings$name, "demo")
})

test_that("command calls run_py_step and wires inputs as symbols", {
  t <- tar_target_py_raw("demo", py_file(),
    inputs = c(x = "up1", y = "up2"), retrieve = "result")
  txt <- paste(deparse(cmd_of(t)), collapse = " ")
  expect_match(txt, "run_py_step")
  # upstream targets appear as bare symbols -> dependencies
  expect_true(all(c("up1", "up2") %in% all.vars(cmd_of(t))))
})

test_that("format defaults: rds for object, file for output = 'file'", {
  t_obj <- tar_target_py_raw("a", py_file(), retrieve = "result")
  expect_identical(t_obj$settings$format, "rds")

  t_file <- tar_target_py_raw("b", py_file(), output = "file", files = "x.txt")
  expect_identical(t_file$settings$format, "file")
})

test_that("explicit format overrides the file-mode default", {
  t <- tar_target_py_raw("c", py_file(), output = "file",
    files = "x.txt", format = "rds")
  expect_identical(t$settings$format, "rds")
})

test_that("name and script are validated", {
  expect_error(tar_target_py_raw(123, py_file()), "single non-empty string")
  expect_error(tar_target_py_raw("", py_file()), "single non-empty string")
  expect_error(tar_target_py_raw("d", 123), "single non-empty")
})

test_that("output mode is validated at construction", {
  expect_error(tar_target_py_raw("e", py_file(), output = "bogus"))
})

test_that("tar_target_py (NSE) deparses a bare name", {
  f <- py_file()
  t <- tar_target_py(py_nse, f, retrieve = "result")
  expect_identical(t$settings$name, "py_nse")
})

test_that("pattern is forwarded (dynamic branching)", {
  t <- tar_target_py_raw("f", py_file(), inputs = c(x = "up"),
    retrieve = "result", pattern = quote(map(up)))
  expect_false(is.null(t$settings$pattern))
})

test_that("tar_target_path() on script/pre_script/post_script wires them as dependencies", {
  t <- tar_target_py_raw("h", tar_target_path("up_script"),
    pre_script = tar_target_path("up_pre"),
    post_script = tar_target_path("up_post"),
    retrieve = "result")
  vars <- all.vars(cmd_of(t))
  expect_true(all(c("up_script", "up_pre", "up_post") %in% vars))
})

test_that("tar_target_path() on script does not affect a literal pre_script/post_script", {
  t <- tar_target_py_raw("i", tar_target_path("up_script"),
    pre_script = py_file(), post_script = py_file(), retrieve = "result")
  txt <- paste(deparse(cmd_of(t)), collapse = " ")
  expect_true("up_script" %in% all.vars(cmd_of(t)))
  # the literal pre/post-script paths are embedded as quoted string constants,
  # not symbols, so they are not picked up as dependencies
  expect_match(txt, 'pre_script = "')
  expect_match(txt, 'post_script = "')
})

test_that("a literal string script is unaffected (backward compatible, untracked)", {
  f <- py_file()
  t <- tar_target_py_raw("j", f, retrieve = "result")
  expect_false("f" %in% all.vars(cmd_of(t)))
  txt <- paste(deparse(cmd_of(t)), collapse = " ")
  expect_match(txt, "script = \"")
})

# Reconstruct the object embedded for a given argument of the run_*_step() command.
arg_obj <- function(target, arg) eval(cmd_of(target)[[arg]])

test_that("tar_code() inline script embeds source (single line) not a path/dependency", {
  t <- tar_target_py_raw("k1", tar_code("result = float(sum(x))"),
    inputs = c(x = "up"), retrieve = "result")
  obj <- arg_obj(t, "script")
  expect_s3_class(obj, "tp_source")
  expect_identical(obj$code, "result = float(sum(x))")
  # the code string is a constant, not a bare-symbol dependency
  expect_false("result" %in% all.vars(cmd_of(t)))
})

test_that("tar_code() inline script embeds dedented multiline source", {
  t <- tar_target_py_raw("k2", tar_code("
      import numpy as np
      result = float(np.sum(x))
    "), inputs = c(x = "up"), retrieve = "result")
  obj <- arg_obj(t, "script")
  expect_s3_class(obj, "tp_source")
  expect_identical(obj$code, "import numpy as np\nresult = float(np.sum(x))")
})

test_that("tar_code({}) inline R pre/post embed as an R-expression carrier", {
  t <- tar_target_py_raw("k3", py_file(),
    pre_script = tar_code({ to_py <- list(x = x) }),
    post_script = tar_code({ py_get("result") }),
    inputs = c(x = "up"))
  pre <- arg_obj(t, "pre_script")
  expect_s3_class(pre, "tp_expr")
  expect_true("to_py" %in% all.vars(pre$code))
  expect_s3_class(arg_obj(t, "post_script"), "tp_expr")
})

test_that("an R { } block is rejected as the foreign script", {
  expect_error(
    tar_target_py_raw("k4", tar_code({ 1 + 1 }), retrieve = "result"),
    "cannot be an R"
  )
})

test_that("python_version and env selection are carried into the command", {
  t <- tar_target_py_raw("g", py_file(), retrieve = "result",
    python_version = "3.12", env_manager = "uv", env = ".venv")
  txt <- paste(deparse(cmd_of(t)), collapse = " ")
  expect_match(txt, 'python_version = "3.12"')
  expect_match(txt, 'env_manager = "uv"')
  expect_match(txt, 'env = ".venv"')
})
