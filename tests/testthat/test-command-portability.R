# A target's command hash is what `targets` compares to decide whether a step
# is outdated. If anything machine-specific is spliced into the command while
# the target is being *constructed*, a store copied to another computer shows
# every tarpolyglot step as outdated even though nothing about the analysis
# changed. These tests pin that down: build the same target under conditions
# that differ only by machine (working directory, options) and require the
# command to come out identical.
#
# Found 2026-10-07 moving a pipeline from a NAS to Windows: `julia_home`
# defaulted to getOption("tarpolyglot.julia_home") in the constructors, so a
# project that set that option (the natural place being .Rprofile) baked this
# machine's Julia path into every Julia step's command.

cmd_hash <- function(target) target$command$hash

# Build `expr` in a throwaway project directory, so the only thing that varies
# between calls is the absolute path of that directory.
in_project <- function(code) {
  d <- withr::local_tempdir()
  dir.create(file.path(d, "py"), showWarnings = FALSE)
  dir.create(file.path(d, "jl"), showWarnings = FALSE)
  dir.create(file.path(d, ".venv"), showWarnings = FALSE)
  writeLines("result = 1", file.path(d, "py/step.py"))
  writeLines("result = 1", file.path(d, "jl/step.jl"))
  writeLines("to_py <- list(x = x)", file.path(d, "pre.R"))
  withr::with_dir(d, force(code))
}

test_that("a Python step's command does not depend on where the project lives", {
  build <- function() {
    tar_target_py(
      name = py_step, script = "py/step.py", pre_script = "pre.R",
      inputs = c(x = "up"), env = ".venv", env_manager = "uv",
      retrieve = "result"
    )
  }
  expect_identical(
    cmd_hash(in_project(build())),
    cmd_hash(in_project(build()))
  )
})

test_that("an existing relative `env` is not absolutised into the command", {
  # `.venv` exists in the project, which is exactly the case
  # .tp_resolve_env_path() absolutises -- but it must only do so at run time.
  t <- in_project(tar_target_py(
    name = py_step, script = "py/step.py",
    env = ".venv", env_manager = "uv", retrieve = "result"
  ))
  txt <- paste(deparse(t$command$expr), collapse = " ")
  expect_match(txt, 'env = ".venv"', fixed = TRUE)
})

test_that("a Julia step's command does not depend on tarpolyglot.julia_home", {
  build <- function(home) {
    withr::with_options(list(tarpolyglot.julia_home = home), {
      in_project(tar_target_jl(
        name = jl_step, script = "jl/step.jl", retrieve = "result"
      ))
    })
  }
  # Two machines with different Julia installs, and one with the option unset.
  expect_identical(cmd_hash(build("/volume2/@appstore/julia/bin")),
    cmd_hash(build("C:/Users/someone/.julia/juliaup/bin")))
  expect_identical(cmd_hash(build("/volume2/@appstore/julia/bin")),
    cmd_hash(build(NULL)))

  # And the path must not be visible in the command text at all.
  txt <- paste(deparse(build("/volume2/@appstore/julia/bin")$command$expr),
    collapse = " ")
  expect_false(grepl("volume2", txt, fixed = TRUE))
})

test_that("the Julia runner still honours tarpolyglot.julia_home at run time", {
  # Dropping the constructor default must not lose the option: the resolver is
  # now the single place that reads it, and an explicit NULL has to fall back.
  seen <- NULL
  local_mocked_bindings(
    .tp_bind_julia = function(f) {
      seen <<- "bound"
      invisible(TRUE)
    }
  )
  withr::with_options(list(tarpolyglot.julia_home = "/some/julia/bin"), {
    expect_silent(.tp_resolve_julia(julia_home = NULL))
  })
  expect_identical(seen, "bound")
})
