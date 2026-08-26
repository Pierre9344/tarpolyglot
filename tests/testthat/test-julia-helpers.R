# Structural tests for the Julia binding helpers. None of these start Julia:
# they cover juliaup path resolution and the JULIA_PROJECT handling, which run
# before JuliaCall is touched. Live binding is covered by
# test-integration-julia.R.

# Build a fake juliaup depot containing the given build directory names.
fake_depot <- function(builds) {
  depot <- withr::local_tempdir(.local_envir = parent.frame())
  for (b in builds) {
    dir.create(file.path(depot, "juliaup", b, "bin"), recursive = TRUE)
  }
  depot
}

test_that(".tp_juliaup_home resolves a version to its bin directory", {
  depot <- fake_depot("julia-1.11.2+0.x64.w64.mingw32")
  withr::local_envvar(JULIA_DEPOT_PATH = depot)
  home <- .tp_juliaup_home("1.11")
  expect_true(dir.exists(home))
  expect_identical(basename(home), "bin")
  expect_match(home, "julia-1.11.2", fixed = TRUE)
})

test_that(".tp_juliaup_home picks the highest version numerically, not lexicographically", {
  # A lexicographic sort ranks "julia-1.9" above "julia-1.12"; the numeric
  # ordering this helper uses must prefer 1.12.
  depot <- fake_depot(c("julia-1.9.4+0.x64", "julia-1.12.6+0.x64"))
  withr::local_envvar(JULIA_DEPOT_PATH = depot)
  expect_match(.tp_juliaup_home("1."), "julia-1.12.6", fixed = TRUE)
})

test_that(".tp_juliaup_home errors when no matching version is installed", {
  depot <- fake_depot(character(0))
  withr::local_envvar(JULIA_DEPOT_PATH = depot)
  expect_error(.tp_juliaup_home("1.11"), "No juliaup Julia matching version '1.11'")
})

test_that(".tp_juliaup_home lists what is installed when the requested version is missing", {
  depot <- fake_depot("julia-1.10.11+0.x64")
  withr::local_envvar(JULIA_DEPOT_PATH = depot)
  expect_error(.tp_juliaup_home("1.99"), "Installed: julia-1.10.11")
})

test_that(".tp_juliaup_home uses only the first entry of a multi-value JULIA_DEPOT_PATH", {
  depot <- fake_depot("julia-1.11.2+0.x64")
  withr::local_envvar(
    JULIA_DEPOT_PATH = paste(depot, file.path(tempdir(), "tp-second-depot"),
      sep = .Platform$path.sep)
  )
  expect_match(.tp_juliaup_home("1.11"), "julia-1.11.2", fixed = TRUE)
})

test_that(".tp_bind_julia clears an ambient JULIA_PROJECT while binding, then restores it", {
  withr::local_envvar(JULIA_PROJECT = "/tp/fake/project")
  seen <- "unset-marker"
  expect_error(
    .tp_bind_julia(function() {
      seen <<- Sys.getenv("JULIA_PROJECT", unset = NA_character_)
      stop("stopped before JuliaCall is reached")
    }),
    "stopped before JuliaCall"
  )
  expect_true(is.na(seen))
  expect_identical(Sys.getenv("JULIA_PROJECT"), "/tp/fake/project")
})

test_that(".tp_bind_julia leaves an unset JULIA_PROJECT alone and returns TRUE", {
  withr::local_envvar(JULIA_PROJECT = NA)
  expect_true(.tp_bind_julia(function() invisible(NULL)))
  expect_identical(Sys.getenv("JULIA_PROJECT", unset = NA_character_), NA_character_)
})

test_that(".tp_resolve_julia sets up Julia and activates a project and packages", {
  skip_if_not_installed("testthat", "3.2.0")
  setup_args <- NULL
  cmds <- character(0)
  local_mocked_bindings(
    julia_setup = function(...) {
      setup_args <<- list(...)
      invisible(NULL)
    },
    julia_command = function(cmd, ...) {
      cmds <<- c(cmds, cmd)
      invisible(NULL)
    },
    .package = "JuliaCall"
  )

  expect_true(.tp_resolve_julia(
    julia_home = "/tp/fake/julia/bin",
    julia_project = "/tp/proj",
    julia_packages = c("DataFrames", "Plots")
  ))

  expect_identical(setup_args$JULIA_HOME, "/tp/fake/julia/bin")
  expect_false(setup_args$installJulia)
  expect_match(cmds[[1L]], "Pkg.activate(raw\"/tp/proj\")", fixed = TRUE)
  expect_identical(cmds[-1L], c("using DataFrames", "using Plots"))
})

test_that(".tp_resolve_julia omits JULIA_HOME and Pkg calls when nothing is requested", {
  skip_if_not_installed("testthat", "3.2.0")
  setup_args <- NULL
  cmds <- character(0)
  local_mocked_bindings(
    julia_setup = function(...) {
      setup_args <<- list(...)
      invisible(NULL)
    },
    julia_command = function(cmd, ...) {
      cmds <<- c(cmds, cmd)
      invisible(NULL)
    },
    .package = "JuliaCall"
  )

  expect_true(.tp_resolve_julia(julia_home = NULL))
  expect_false("JULIA_HOME" %in% names(setup_args))
  expect_length(cmds, 0L)
})

test_that(".tp_resolve_julia resolves julia_version through juliaup before binding", {
  # With no julia_home, a julia_version must go through .tp_juliaup_home(),
  # which errors here because the depot is empty. That proves the resolution
  # branch ran without starting Julia.
  depot <- fake_depot(character(0))
  withr::local_envvar(JULIA_DEPOT_PATH = depot)
  expect_error(
    .tp_resolve_julia(julia_version = "1.11", julia_home = NULL),
    "No juliaup Julia matching version"
  )
})
