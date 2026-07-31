# tarpolyglot_map() and the compile-once expansion of tar_target_rs(). No Rust
# toolchain needed: we only build/inspect target objects and the normalizer.

rs_file <- function() {
  f <- withr::local_tempfile(fileext = ".rs", .local_envir = parent.frame())
  writeLines("#[extendr]\nfn square(x: f64) -> f64 { x * x }", f)
  f
}
cmd_txt <- function(target) paste(deparse(target$command$expr), collapse = " ")

test_that(".tp_pattern leaves a plain map() unchanged", {
  r <- .tp_pattern(quote(map(x)))
  expect_false(r$compile_once)
  expect_identical(r$pattern, quote(map(x)))
})

test_that(".tp_pattern rewrites tarpolyglot_map() to map() and flags compile_once", {
  r <- .tp_pattern(quote(tarpolyglot_map(x)))
  expect_true(r$compile_once)
  expect_identical(r$pattern, quote(map(x)))
})

test_that(".tp_pattern accepts the namespaced tarpolyglot::tarpolyglot_map()", {
  r <- .tp_pattern(quote(tarpolyglot::tarpolyglot_map(x)))
  expect_true(r$compile_once)
  expect_identical(r$pattern, quote(map(x)))
})

test_that(".tp_pattern handles NULL", {
  r <- .tp_pattern(NULL)
  expect_false(r$compile_once)
  expect_null(r$pattern)
})

test_that("tarpolyglot_map() errors if called directly", {
  expect_error(tarpolyglot_map(x), "only meant to be used")
})

test_that("every helper rewrites to its targets equivalent and flags compile_once", {
  mapping <- c(tarpolyglot_map = "map", tarpolyglot_cross = "cross",
    tarpolyglot_slice = "slice", tarpolyglot_head = "head",
    tarpolyglot_tail = "tail", tarpolyglot_sample = "sample")
  for (nm in names(mapping)) {
    call_in <- as.call(list(as.name(nm), quote(x)))
    call_out <- as.call(list(as.name(mapping[[nm]]), quote(x)))
    r <- .tp_pattern(call_in)
    expect_true(r$compile_once, info = nm)
    expect_identical(r$pattern, call_out, info = nm)
  }
})

test_that("helper arguments (n / index) pass through the rewrite unchanged", {
  expect_identical(.tp_pattern(quote(tarpolyglot_head(x, n = 2)))$pattern,
    quote(head(x, n = 2)))
  expect_identical(.tp_pattern(quote(tarpolyglot_slice(x, index = c(1, 3))))$pattern,
    quote(slice(x, index = c(1, 3))))
  expect_identical(.tp_pattern(quote(tarpolyglot_cross(a, b)))$pattern,
    quote(cross(a, b)))
})

test_that("each helper errors if called directly", {
  expect_error(tarpolyglot_cross(x), "only meant to be used")
  expect_error(tarpolyglot_slice(x, index = 1), "only meant to be used")
  expect_error(tarpolyglot_head(x, n = 1), "only meant to be used")
  expect_error(tarpolyglot_tail(x, n = 1), "only meant to be used")
  expect_error(tarpolyglot_sample(x, n = 1), "only meant to be used")
})

# Representative plain-targets pattern calls, and the matching tarpolyglot call
# (same expression with the head symbol swapped to tarpolyglot_<name>).
.plain_calls <- list(
  map = quote(map(a)),
  cross = quote(cross(a, b)),
  slice = quote(slice(a, index = c(1, 2))),
  head = quote(head(a, n = 2)),
  tail = quote(tail(a, n = 2)),
  sample = quote(sample(a, n = 2))
)
.tp_call <- function(plain) {
  plain[[1L]] <- as.name(paste0("tarpolyglot_", as.character(plain[[1L]])))
  plain
}

test_that("on Python, every helper reverts to the identical plain targets pattern", {
  py <- withr::local_tempfile(fileext = ".py")
  writeLines("result = float(x)", py)
  build <- function(pat) {
    tar_target_py_raw("t", py, inputs = c(x = "a"), retrieve = "result",
      pattern = pat)$settings$pattern
  }
  for (k in names(.plain_calls)) {
    plain <- .plain_calls[[k]]
    got <- build(.tp_call(plain))
    expect_identical(got, build(plain), info = k)          # same target
    expect_no_match(paste(deparse(got), collapse = " "), "tarpolyglot_", info = k)
  }
})

test_that("on Julia, every helper reverts to the identical plain targets pattern", {
  jl <- withr::local_tempfile(fileext = ".jl")
  writeLines("result = float(x)", jl)
  build <- function(pat) {
    tar_target_jl_raw("t", jl, inputs = c(x = "a"), retrieve = "result",
      pattern = pat)$settings$pattern
  }
  for (k in names(.plain_calls)) {
    plain <- .plain_calls[[k]]
    got <- build(.tp_call(plain))
    expect_identical(got, build(plain), info = k)
    expect_no_match(paste(deparse(got), collapse = " "), "tarpolyglot_", info = k)
  }
})

test_that("on Rust, every helper expands to a compile target + a branch with the plain pattern", {
  for (k in names(.plain_calls)) {
    plain <- .plain_calls[[k]]
    out <- tar_target_rs_raw("rs_h", rs_file(), inputs = c(x = "a"),
      post_script = "post.R", pattern = .tp_call(plain))
    expect_type(out, "list")
    nms <- vapply(out, function(t) t$settings$name, character(1))
    expect_setequal(nms, c("rs_h_rust_lib", "rs_h"))
    br <- out[[which(nms == "rs_h")]]
    # targets stores the pattern wrapped as expression(<pattern>); unwrap to compare.
    expect_identical(br$settings$pattern[[1L]], plain, info = k)  # branches on the plain pattern
    expect_true("rs_h_rust_lib" %in% br$deps, info = k)
  }
})

test_that("Rust compile-once expansion works for a non-map helper (cross)", {
  out <- tar_target_rs_raw("rs_x", rs_file(), inputs = c(x = "a", y = "b"),
    post_script = "post.R", pattern = quote(tarpolyglot_cross(a, b)))
  nms <- vapply(out, function(t) t$settings$name, character(1))
  expect_setequal(nms, c("rs_x_rust_lib", "rs_x"))
  br <- out[[which(nms == "rs_x")]]
  expect_match(paste(deparse(br$settings$pattern), collapse = " "), "cross\\(a, b\\)")
  expect_true("rs_x_rust_lib" %in% br$deps)
})

test_that("Rust + tarpolyglot_map() expands to a compile target and a branch target", {
  out <- tar_target_rs_raw("rs_b", rs_file(), inputs = c(x = "vals"),
    post_script = "post.R", pattern = quote(tarpolyglot_map(vals)))
  expect_type(out, "list")
  expect_false(inherits(out, "tar_target"))
  nms <- vapply(out, function(t) t$settings$name, character(1))
  expect_setequal(nms, c("rs_b_rust_lib", "rs_b"))

  lib <- out[[which(nms == "rs_b_rust_lib")]]
  br <- out[[which(nms == "rs_b")]]

  # Compile target: not branched, compiles the crate.
  expect_null(lib$settings$pattern)
  expect_match(cmd_txt(lib), "compile_rs_lib")

  # Branch target: branches over vals, depends on the compile target, reuses it.
  expect_false(is.null(br$settings$pattern))
  expect_true("rs_b_rust_lib" %in% br$deps)
  expect_match(cmd_txt(br), "run_rs_step_prebuilt")
  expect_no_match(cmd_txt(br), "compile_rs_lib")
})

test_that("Rust + plain map() stays a single, self-compiling target", {
  t <- tar_target_rs_raw("rs_c", rs_file(), inputs = c(x = "vals"),
    post_script = "post.R", pattern = quote(map(vals)))
  expect_s3_class(t, "tar_target")
  expect_match(cmd_txt(t), "run_rs_step\\(")
})

test_that("Rust + tarpolyglot_map() carries build args onto the compile target", {
  out <- tar_target_rs_raw("rs_d", rs_file(), inputs = c(x = "vals"),
    post_script = "post.R", pattern = quote(tarpolyglot_map(vals)),
    toolchain = "stable-x86_64-pc-windows-gnu",
    dependencies = list(serde_json = "1"))
  nms <- vapply(out, function(t) t$settings$name, character(1))
  lib <- out[[which(nms == "rs_d_rust_lib")]]
  expect_match(cmd_txt(lib), "stable-x86_64-pc-windows-gnu")
  expect_match(cmd_txt(lib), "serde_json")
})

test_that("Python + tarpolyglot_map() degrades to map() in a single target", {
  py <- withr::local_tempfile(fileext = ".py")
  writeLines("result = float(x)", py)
  t <- tar_target_py_raw("py_b", py, inputs = c(x = "vals"),
    retrieve = "result", pattern = quote(tarpolyglot_map(vals)))
  expect_s3_class(t, "tar_target")
  ptxt <- paste(deparse(t$settings$pattern), collapse = " ")
  expect_match(ptxt, "map\\(vals\\)")
  expect_no_match(ptxt, "tarpolyglot_map")
})

test_that("Julia + tarpolyglot_map() degrades to map() in a single target", {
  jl <- withr::local_tempfile(fileext = ".jl")
  writeLines("result = float(x)", jl)
  t <- tar_target_jl_raw("jl_b", jl, inputs = c(x = "vals"),
    retrieve = "result", pattern = quote(tarpolyglot_map(vals)))
  expect_s3_class(t, "tar_target")
  ptxt <- paste(deparse(t$settings$pattern), collapse = " ")
  expect_match(ptxt, "map\\(vals\\)")
  expect_no_match(ptxt, "tarpolyglot_map")
})
