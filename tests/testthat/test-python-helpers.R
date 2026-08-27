# Structural tests for the Python binding helpers. None of these bind an
# interpreter: they exercise the path resolution and the argument-validation
# branches, which all raise before reticulate is ever called. The cases that
# genuinely bind are covered by test-integration-python.R.

test_that(".tp_resolve_env_path passes NULL and non-existent names through untouched", {
  expect_null(.tp_resolve_env_path(NULL))
  # A bare name that is not a directory is a named-environment lookup, not a
  # path, so it must not be rewritten.
  expect_identical(.tp_resolve_env_path("tp-not-a-directory-xyz"), "tp-not-a-directory-xyz")
})

test_that(".tp_resolve_env_path normalises an existing directory to an absolute path", {
  d <- withr::local_tempdir()
  # local_dir() changes and restores the working directory for the duration of
  # the test, so no bare setwd() is needed.
  withr::local_dir(dirname(d))
  rel <- basename(d)
  res <- .tp_resolve_env_path(rel)
  expect_true(res != rel)
  expect_true(dir.exists(res))
  expect_identical(res, normalizePath(rel, winslash = "/", mustWork = TRUE))
})

test_that(".tp_poetry_venv errors clearly when poetry cannot resolve a venv", {
  withr::local_options(tarpolyglot.poetry = "tp-definitely-not-poetry-xyz")
  expect_error(
    suppressWarnings(.tp_poetry_venv(".")),
    "Could not resolve a poetry virtualenv"
  )
})

test_that(".tp_bind clears an ambient RETICULATE_PYTHON while binding, then restores it", {
  withr::local_envvar(RETICULATE_PYTHON = "/tp/fake/python")
  seen <- "unset-marker"
  expect_error(
    .tp_bind(function() {
      seen <<- Sys.getenv("RETICULATE_PYTHON", unset = NA_character_)
      stop("stopped before reticulate is reached")
    }),
    "stopped before reticulate"
  )
  # The ambient value must not be visible to the binding function ...
  expect_true(is.na(seen))
  # ... and must be back in place afterwards, even though bind_fn() errored.
  expect_identical(Sys.getenv("RETICULATE_PYTHON"), "/tp/fake/python")
})

test_that(".tp_bind leaves an unset RETICULATE_PYTHON alone", {
  withr::local_envvar(RETICULATE_PYTHON = NA)
  expect_error(.tp_bind(function() stop("boom")), "boom")
  expect_identical(Sys.getenv("RETICULATE_PYTHON", unset = NA_character_), NA_character_)
})

test_that(".tp_resolve_python rejects an unknown env_manager", {
  expect_error(.tp_resolve_python(env_manager = "not-a-manager"), "'arg' should be one of")
})

test_that(".tp_resolve_python rejects `env` combined with env_manager = 'system'", {
  expect_error(
    .tp_resolve_python(env = "some-env", env_manager = "system"),
    "`env` was supplied but `env_manager` is 'system'"
  )
})

test_that(".tp_resolve_python requires `env` for the virtualenv-style managers", {
  for (mgr in c("virtualenv", "venv", "uv")) {
    expect_error(
      .tp_resolve_python(env = NULL, env_manager = mgr),
      "is required for"
    )
  }
})

test_that(".tp_resolve_python requires `env` for env_manager = 'conda'", {
  expect_error(
    .tp_resolve_python(env = NULL, env_manager = "conda"),
    "conda environment name"
  )
})

# The successful binds below mock reticulate itself, so the precedence rules
# can be checked without any interpreter being bound.
mock_reticulate <- function(env = parent.frame()) {
  calls <- new.env(parent = emptyenv())
  testthat::local_mocked_bindings(
    use_python = function(python, required = TRUE) {
      calls$use_python <- python
      invisible(NULL)
    },
    use_virtualenv = function(virtualenv, required = TRUE) {
      calls$use_virtualenv <- virtualenv
      invisible(NULL)
    },
    use_condaenv = function(condaenv, required = TRUE) {
      calls$use_condaenv <- condaenv
      invisible(NULL)
    },
    py_require = function(python_version, ...) {
      calls$py_require <- python_version
      invisible(NULL)
    },
    py_config = function(...) list(python = "/tp/fake/python"),
    .package = "reticulate", .env = env
  )
  calls
}

test_that(".tp_resolve_python binds an explicit interpreter path first", {
  skip_if_not_installed("testthat", "3.2.0")
  calls <- mock_reticulate()
  .tp_resolve_python(python = "/tp/fake/python")
  expect_identical(calls$use_python, "/tp/fake/python")
})

test_that(".tp_resolve_python warns that python_version is ignored beside an explicit path", {
  skip_if_not_installed("testthat", "3.2.0")
  calls <- mock_reticulate()
  expect_warning(
    .tp_resolve_python(python = "/tp/fake/python", python_version = "3.12"),
    "ignored when an explicit `python` path is set"
  )
  expect_identical(calls$use_python, "/tp/fake/python")
})

test_that(".tp_resolve_python binds a virtualenv for the virtualenv-style managers", {
  skip_if_not_installed("testthat", "3.2.0")
  for (mgr in c("virtualenv", "venv", "uv")) {
    calls <- mock_reticulate()
    .tp_resolve_python(env = "tp-venv-name", env_manager = mgr)
    expect_identical(calls$use_virtualenv, "tp-venv-name", label = mgr)
  }
})

test_that(".tp_resolve_python binds a conda environment by name", {
  skip_if_not_installed("testthat", "3.2.0")
  calls <- mock_reticulate()
  .tp_resolve_python(env = "tp-conda-env", env_manager = "conda")
  expect_identical(calls$use_condaenv, "tp-conda-env")
})

test_that(".tp_resolve_python resolves a poetry project to its virtualenv", {
  skip_if_not_installed("testthat", "3.2.0")
  calls <- mock_reticulate()
  local_mocked_bindings(.tp_poetry_venv = function(project) "/tp/poetry/venv")
  .tp_resolve_python(env = "tp-project", env_manager = "poetry")
  expect_identical(calls$use_virtualenv, "/tp/poetry/venv")
})

test_that(".tp_resolve_python asks reticulate for a version when only python_version is set", {
  skip_if_not_installed("testthat", "3.2.0")
  calls <- mock_reticulate()
  .tp_resolve_python(python_version = "3.12")
  expect_identical(calls$py_require, "3.12")
  expect_null(calls$use_python)
})

test_that(".tp_resolve_python leaves reticulate's default alone when nothing is set", {
  skip_if_not_installed("testthat", "3.2.0")
  calls <- mock_reticulate()
  .tp_resolve_python()
  expect_null(calls$py_require)
  expect_null(calls$use_python)
})

test_that(".tp_resolve_python warns that python_version is ignored when an env is selected", {
  # The warning fires before the (here deliberately failing) bind, so both the
  # warning branch and the missing-`env` branch are exercised in one call.
  expect_warning(
    expect_error(.tp_resolve_python(python_version = "3.12", env_manager = "virtualenv")),
    "python_version` is ignored when an environment is selected"
  )
})
