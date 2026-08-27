# Unit tests for the internal helpers. These need no Python/Julia.

test_that(".tp_name handles symbols and strings", {
  expect_identical(.tp_name(quote(my_target)), "my_target")
  expect_identical(.tp_name("my_target"), "my_target")
})

test_that(".tp_match_output validates the mode", {
  expect_identical(.tp_match_output("object"), "object")
  expect_identical(.tp_match_output("file"), "file")
  expect_error(.tp_match_output("nope"))
})

test_that(".tp_inputs_call builds a list() call with bare symbols", {
  expect_identical(.tp_inputs_call(NULL), quote(list()))
  expect_identical(.tp_inputs_call(character(0)), quote(list()))

  cl <- .tp_inputs_call(c(x = "up1", y = "up2"))
  # expect_type() compares typeof(), and a call's typeof() is "language" (its
  # *class* is "call"), so "language" is the type to assert here.
  expect_type(cl, "language")
  # The upstream target names appear as bare symbols -> targets sees them as deps.
  expect_setequal(all.vars(cl), c("up1", "up2"))
  # Names on the list() are the in-session names.
  expect_identical(names(as.list(cl))[-1], c("x", "y"))
})

test_that(".tp_inputs_call requires names", {
  expect_error(.tp_inputs_call(c("up1", "up2")), "named")
})

test_that(".tp_assert_script validates paths", {
  expect_error(.tp_assert_script(123, "script"), "single non-empty")
  expect_error(.tp_assert_script(c("a", "b"), "script"), "single non-empty")
  expect_error(.tp_assert_script("", "script"), "single non-empty")

  # must_exist = FALSE (construction time): a missing path is allowed.
  expect_true(.tp_assert_script("does_not_exist.py", "script"))
  # must_exist = TRUE (run time): a missing path errors.
  expect_error(
    .tp_assert_script("does_not_exist.py", "script", must_exist = TRUE),
    "does not exist"
  )

  f <- withr::local_tempfile(fileext = ".py")
  writeLines("x = 1", f)
  expect_true(.tp_assert_script(f, "script", must_exist = TRUE))
})

test_that("tar_target_path validates and marks a target-name string", {
  ref <- tar_target_path("up_script")
  expect_s3_class(ref, "tp_target_ref")
  expect_identical(unclass(ref), "up_script")

  expect_error(tar_target_path(123), "single non-empty")
  expect_error(tar_target_path(character(0)), "single non-empty")
  expect_error(tar_target_path(c("a", "b")), "single non-empty")
  expect_error(tar_target_path(""), "single non-empty")
})

test_that(".tp_script_expr turns a tar_target_path() into a bare symbol", {
  expect_identical(.tp_script_expr(tar_target_path("up_script")), as.name("up_script"))
  # anything else (literal string, NULL) passes through unchanged
  expect_identical(.tp_script_expr("literal/path.py"), "literal/path.py")
  expect_null(.tp_script_expr(NULL))
})

test_that(".tp_assert_script accepts a tar_target_path() reference with nothing to check yet", {
  expect_true(.tp_assert_script(tar_target_path("up_script"), "script"))
  expect_true(.tp_assert_script(tar_target_path("up_script"), "script", must_exist = TRUE))
})

# ---- inline code: tar_code() / .tp_dedent() / carriers -------------------------

test_that(".tp_dedent strips the common margin and keeps relative indentation", {
  code <- "\n    import numpy as np\n    for i in range(3):\n        total += i\n  "
  expect_identical(
    .tp_dedent(code),
    "import numpy as np\nfor i in range(3):\n    total += i"
  )
})

test_that(".tp_dedent leaves already-flush code and single lines unchanged", {
  expect_identical(.tp_dedent("result = sum(x)"), "result = sum(x)")
  expect_identical(.tp_dedent("a\nb\nc"), "a\nb\nc")
})

test_that(".tp_dedent drops leading/trailing blank lines and keeps interior blanks", {
  expect_identical(.tp_dedent("\n\n  a\n\n  b\n\n"), "a\n\nb")
})

test_that(".tp_dedent strips a leading indent from a single line", {
  expect_identical(.tp_dedent("    result = 1"), "result = 1")
})

test_that(".tp_dedent: mixed tabs/spaces shorten (do not expand) the common prefix", {
  # line 1 indented with a space, line 2 with a tab -> no common prefix -> unchanged
  expect_identical(.tp_dedent(" a\n\tb"), " a\n\tb")
})

test_that("tar_code() captures a { } block as an R expression carrier", {
  m <- tar_code({ to_py <- list(x = x) })
  expect_s3_class(m, "tp_inline")
  expect_s3_class(m, "tp_expr")
  # A captured { } block is a call, whose typeof() is "language".
  expect_type(m$code, "language")
})

test_that("inline carriers are internal (not exported)", {
  expect_false("tp_source" %in% getNamespaceExports("tarpolyglot"))
  expect_false("tp_expr" %in% getNamespaceExports("tarpolyglot"))
  expect_true("tar_code" %in% getNamespaceExports("tarpolyglot"))
})

test_that("tar_code() captures a string literal as a (dedented) source carrier", {
  m <- tar_code("result = float(sum(x))")
  expect_s3_class(m, "tp_source")
  expect_identical(m$code, "result = float(sum(x))")

  multi <- tar_code("
    total = 0
    for i in range(len(x)):
        total += x[i]
  ")
  expect_s3_class(multi, "tp_source")
  expect_identical(
    multi$code,
    "total = 0\nfor i in range(len(x)):\n    total += x[i]"
  )
})

test_that("tar_code() accepts a variable or expression yielding a string", {
  src <- "result = 1"
  expect_identical(tar_code(src)$code, "result = 1")
  expect_identical(tar_code(paste0("result", " = 1"))$code, "result = 1")
})

test_that("tar_code() rejects a non-string, non-block argument", {
  expect_error(tar_code(123), "expects inline code")
})

test_that(".tp_script_expr splices inline carriers as self-contained structure() calls", {
  es <- .tp_script_expr(.tp_inline_source("result = 1"))
  expect_identical(
    es,
    quote(structure(list(code = "result = 1"), class = c("tp_inline", "tp_source")))
  )
  # rebuilding it yields the same classed carrier (what happens at run time)
  obj <- eval(es)
  expect_s3_class(obj, "tp_source")
  expect_identical(obj$code, "result = 1")

  ee <- .tp_script_expr(.tp_inline_expr(quote({ a <- 1 })))
  expect_identical(
    ee,
    quote(structure(list(code = quote({ a <- 1 })), class = c("tp_inline", "tp_expr")))
  )
  expect_s3_class(eval(ee), "tp_expr")
})

test_that(".tp_assert_script accepts inline markers with nothing on disk to check", {
  expect_true(.tp_assert_script(.tp_inline_source("x = 1"), "script"))
  expect_true(.tp_assert_script(.tp_inline_source("x = 1"), "script", must_exist = TRUE))
  expect_true(.tp_assert_script(.tp_inline_expr(quote(x <- 1)), "pre_script", must_exist = TRUE))
})

test_that(".tp_eval_script evaluates inline R (expr and source) in the environment", {
  e <- new.env()
  assign("x", 21, envir = e)
  # tp_expr block: last value is returned
  inline <- .tp_inline_expr(quote({
    y <- x * 2
    y
  }))
  expect_identical(.tp_eval_script(inline, e), 42)
  # tp_source string of R: parsed and evaluated
  expect_identical(.tp_eval_script(.tp_inline_source("x + 1"), e), 22)
})
