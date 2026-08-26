# .tp_rs_finish() / .tp_cpp_finish() are the shared tails of the Rust and C++
# workers: given an environment that already holds the compiled functions and
# the upstream inputs, they evaluate the post-script and produce either the
# target value or a vector of file paths. Neither compiles anything, so both
# are testable without a Rust or C++ toolchain.

finishers <- list(rs = .tp_rs_finish, cpp = .tp_cpp_finish)

write_post <- function(code) {
  f <- withr::local_tempfile(fileext = ".R", .local_envir = parent.frame())
  writeLines(code, f)
  f
}

test_that("object mode returns the value of the post-script's last expression", {
  for (nm in names(finishers)) {
    e <- new.env(parent = globalenv())
    assign("x", 21, envir = e)
    post <- write_post("x * 2")
    expect_identical(finishers[[nm]](e, post, "object", NULL), 42, label = nm)
  }
})

test_that("object mode requires a post-script", {
  for (nm in names(finishers)) {
    e <- new.env(parent = globalenv())
    expect_error(
      finishers[[nm]](e, NULL, "object", NULL),
      "needs a `post_script`",
      label = nm
    )
  }
})

test_that("file mode normalises the paths the post-script returns", {
  for (nm in names(finishers)) {
    e <- new.env(parent = globalenv())
    post <- write_post("c('out_one.txt', 'out_two.txt')")
    res <- finishers[[nm]](e, post, "file", NULL)
    expect_length(res, 2L)
    expect_match(res[[1L]], "out_one.txt", fixed = TRUE)
    # normalizePath() makes them absolute even though they do not exist.
    expect_false(identical(res[[1L]], "out_one.txt"))
  }
})

test_that("file mode falls back to `files` when there is no post-script", {
  for (nm in names(finishers)) {
    e <- new.env(parent = globalenv())
    res <- finishers[[nm]](e, NULL, "file", c("from_files.txt"))
    expect_length(res, 1L)
    expect_match(res[[1L]], "from_files.txt", fixed = TRUE)
  }
})

test_that("file mode errors when neither a post-script nor `files` supplies paths", {
  for (nm in names(finishers)) {
    e <- new.env(parent = globalenv())
    expect_error(
      finishers[[nm]](e, NULL, "file", NULL),
      "needs a `post_script` returning paths, or `files`",
      label = nm
    )
  }
})

test_that(".tp_with_rust_build_env leaves an existing R_HOME alone and restores PATH", {
  withr::local_envvar(R_HOME = "/tp/preset/rhome")
  old_path <- Sys.getenv("PATH")
  restore <- .tp_with_rust_build_env()
  expect_identical(Sys.getenv("R_HOME"), "/tp/preset/rhome")
  restore()
  expect_identical(Sys.getenv("R_HOME"), "/tp/preset/rhome")
  expect_identical(Sys.getenv("PATH"), old_path)
})
