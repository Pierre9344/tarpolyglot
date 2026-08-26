# .onLoad() seeds the tarpolyglot.julia_home option from the JULIA_HOME
# environment variable, without ever overriding a value the user set first.
# It is called here directly: at real load time it runs before covr can
# instrument the package, so it needs an explicit call to be exercised.
# Fetched from the namespace because .onLoad is not on the search path that
# test code sees under either pkgload::load_all() or an installed package.

onload <- getFromNamespace(".onLoad", "tarpolyglot")

test_that(".onLoad seeds tarpolyglot.julia_home from JULIA_HOME", {
  withr::local_envvar(JULIA_HOME = "/tp/fake/julia/bin")
  old <- getOption("tarpolyglot.julia_home")
  withr::defer(options(tarpolyglot.julia_home = old))

  options(tarpolyglot.julia_home = NULL)   # assigning NULL removes the option
  onload("lib", "tarpolyglot")
  expect_identical(getOption("tarpolyglot.julia_home"), "/tp/fake/julia/bin")
})

test_that(".onLoad leaves the option unset when JULIA_HOME is unset", {
  withr::local_envvar(JULIA_HOME = NA)
  old <- getOption("tarpolyglot.julia_home")
  withr::defer(options(tarpolyglot.julia_home = old))

  options(tarpolyglot.julia_home = NULL)
  onload("lib", "tarpolyglot")
  expect_null(getOption("tarpolyglot.julia_home"))
})

test_that(".onLoad does not override a value the user already set", {
  withr::local_envvar(JULIA_HOME = "/tp/env/julia/bin")
  withr::local_options(tarpolyglot.julia_home = "/tp/user/julia/bin")
  onload("lib", "tarpolyglot")
  expect_identical(getOption("tarpolyglot.julia_home"), "/tp/user/julia/bin")
})
