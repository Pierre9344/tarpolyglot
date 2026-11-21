# toolchain_check() tests that stand in for something the machine may not have.
#
# Most of toolchain_check() reads the output of a tool (`uv python list`, `rustup toolchain
# list`, a C++ compiler's `--version`) or runs code in a fresh callr worker. On any given
# machine some of those tools are missing, so the branches that parse their output are never
# reached -- on the Linux CI runner that measures coverage, neither uv nor juliaup is installed,
# and on Windows the `.Platform$OS.type != "windows"` compiler checks cannot run at all.
#
# These tests supply the missing piece instead of skipping:
#   * `local_fake_tool()` puts a fake command-line tool on PATH that prints canned output, so
#     the parsers run against a *fixed* sample of a format tarpolyglot does not control;
#   * `callr::r` is replaced by a direct call, so the body of a fresh-worker check runs in this
#     process, with JuliaCall stubbed out;
#   * `.tp_cpp_compiler_cmd()` is stubbed to return a compiler that is absent, silent, or
#     undeterminable.
#
# The live versions of all of this are in test-integration-toolchain-check.R.

# Create an executable `name` that prints `output` and exits 0, whatever arguments it is given,
# and make it the only thing on PATH. Both are undone when the calling test ends.
#
# PATH is *replaced*, not prefixed: on Windows the extension order of PATHEXT outranks the
# order of the directories, so a real `uv.exe` further down PATH still wins over a fake `uv.cmd`
# at the front, and the test would silently measure the machine's own tool instead of the
# sample. Replacing PATH also means the fake must not call anything that is looked up on PATH,
# hence `printf`/`type` (shell builtins) rather than `cat`.
local_fake_tool <- function(name, output = character(0), env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  if (.Platform$OS.type == "windows") {
    payload <- file.path(dir, paste0(name, "-output.txt"))
    writeLines(output, payload)
    exe <- file.path(dir, paste0(name, ".cmd"))
    writeLines(
      c(
        "@echo off",
        paste0("type \"", normalizePath(payload, winslash = "\\"), "\"")
      ),
      exe
    )
  } else {
    exe <- file.path(dir, name)
    writeLines(
      c(
        "#!/bin/sh",
        if (length(output)) {
          paste(
            "printf '%s\\n'",
            paste(shQuote(output, type = "sh"), collapse = " ")
          )
        } else {
          ":"
        }
      ),
      exe
    )
    Sys.chmod(exe, "0755")
  }
  withr::local_path(dir, action = "replace", .local_envir = env)
  invisible(exe)
}

test_that("local_fake_tool() really puts a runnable tool on PATH", {
  # If this fails, every test below is testing nothing, so it is checked once here.
  local_fake_tool("tp-fake-echo-tool", c("line one", "line two"))
  expect_true(nzchar(Sys.which("tp-fake-echo-tool")))
  expect_identical(
    trimws(system2("tp-fake-echo-tool", "--version", stdout = TRUE)),
    c("line one", "line two")
  )
})

# --------------------------------------------------------------------------
# .tp_python_versions(): parsing `uv python list --only-installed`
# --------------------------------------------------------------------------

# One installed interpreter per line, two columns: uv's own key, then the path. The
# "<download available>" lines uv prints for versions it could fetch have a space in the second
# column, which is how they are told apart from installed ones.
uv_sample <- c(
  "cpython-3.13.1-linux-x86_64-gnu     /home/u/.local/share/uv/python/cpython-3.13.1-linux-x86_64-gnu/bin/python3",
  "cpython-3.12.8-linux-x86_64-gnu     /usr/bin/python3.12",
  "cpython-3.14.0-linux-x86_64-gnu     <download available>"
)

test_that(".tp_python_versions parses uv's installed list and marks the resolved version", {
  local_fake_tool("uv", uv_sample)
  v <- .tp_python_versions(resolved_version = "3.12.8")

  expect_s3_class(v, "data.frame")
  # The "<download available>" row is not an installed interpreter.
  expect_identical(nrow(v), 2L)
  expect_identical(v$version, c("3.13.1", "3.12.8"))
  expect_identical(v$path[[2]], "/usr/bin/python3.12")
  expect_identical(v$default, c(FALSE, TRUE))
})

test_that(".tp_python_versions falls back to matching the resolved path", {
  # reticulate's default interpreter can be an ephemeral uv-provisioned one, whose version
  # string is not in the installed list even though the path is; and the match is
  # case-insensitive, because Windows paths are.
  local_fake_tool("uv", uv_sample)
  v <- .tp_python_versions(
    resolved_version = "3.11.9",
    resolved_path = "/USR/bin/python3.12"
  )
  expect_identical(v$default, c(FALSE, TRUE))

  # No version and no path to match: nothing is the default, but the versions are still listed.
  v2 <- .tp_python_versions()
  expect_identical(v2$version, c("3.13.1", "3.12.8"))
  expect_false(any(v2$default))
})

test_that(".tp_python_versions returns NULL when uv lists nothing installed", {
  local_fake_tool("uv")
  expect_null(.tp_python_versions("3.12.8"))
})

test_that(".tp_python_versions returns NULL when no line looks like an installed version", {
  # Only downloadable versions: the space inside "<download available>" makes three columns,
  # which is exactly what keeps these lines out of the installed list.
  local_fake_tool(
    "uv",
    c(
      "cpython-3.14.0-linux-x86_64-gnu              <download available>",
      "cpython-3.13.0+freethreaded-linux-x86_64-gnu <download available>"
    )
  )
  expect_null(.tp_python_versions("3.12.8"))
})

# --------------------------------------------------------------------------
# .tp_rust_toolchains(): parsing `rustup toolchain list -v`
# --------------------------------------------------------------------------

test_that(".tp_rust_toolchains parses rustup's list and takes its inline (default) mark", {
  local_fake_tool(
    "rustup",
    c(
      "stable-x86_64-unknown-linux-gnu (active, default)\t/home/u/.rustup/toolchains/stable-x86_64-unknown-linux-gnu",
      "nightly-x86_64-unknown-linux-gnu\t/home/u/.rustup/toolchains/nightly-x86_64-unknown-linux-gnu"
    )
  )
  v <- .tp_rust_toolchains()

  expect_identical(nrow(v), 2L)
  # The "(active, default)" parenthetical belongs to the mark, not to the name.
  expect_identical(
    v$version,
    c("stable-x86_64-unknown-linux-gnu", "nightly-x86_64-unknown-linux-gnu")
  )
  expect_identical(v$default, c(TRUE, FALSE))
})

test_that(".tp_rust_toolchains returns NULL when rustup prints nothing parseable", {
  local_fake_tool("rustup")
  expect_null(.tp_rust_toolchains())

  local_fake_tool("rustup", "no installed toolchains")
  expect_null(.tp_rust_toolchains())
})

test_that(".tp_check_rs reports a rustup that names no active toolchain", {
  # `rustup show active-toolchain` prints nothing outside a Rust project, so the row carries
  # the path alone, with no "(active: ...)" suffix.
  local_fake_tool("rustup")
  res <- suppressWarnings(.tp_check_rs(deep = FALSE, quiet = TRUE))
  row <- res[res$check == "rustup", ]
  expect_identical(row$status, "ok")
  expect_false(grepl("active:", row$detail, fixed = TRUE))
})

# --------------------------------------------------------------------------
# .tp_which_check(): a tool that is present but says nothing
# --------------------------------------------------------------------------

test_that(".tp_which_check reports a present tool whose --version prints nothing", {
  local_fake_tool("tp-fake-silent-tool")
  row <- .tp_which_check("py", "silent", "tp-fake-silent-tool", quiet = TRUE)
  expect_identical(row$status, "ok")
  # The version parenthetical is dropped rather than left empty.
  expect_false(grepl("()", row$detail, fixed = TRUE))
  expect_match(row$detail, "tp-fake-silent-tool")
})

# --------------------------------------------------------------------------
# The fresh-worker checks, run in this process
# --------------------------------------------------------------------------

test_that(".tp_run_check announces a slow check before it starts", {
  expect_message(
    .tp_run_check(
      "py",
      "x",
      quiet = FALSE,
      pre_msg = "Checking something slow...",
      fn = function() .tp_check_row("py", "x", "ok", "")
    ),
    "Checking something slow"
  )
})

test_that("every fresh-worker check degrades to a fail row without callr", {
  skip_if_not_installed("testthat", "3.2.0")
  # callr is in Suggests, so this is the shape of a machine that installed tarpolyglot without
  # it: each check must report the missing package, not abort the diagnostic.
  local_mocked_bindings(
    .tp_require_callr = function(toolchain, check) {
      .tp_check_row(
        toolchain,
        check,
        "fail",
        "the 'callr' package is required for this check"
      )
    }
  )
  rows <- rbind(
    suppressWarnings(.tp_check_py(deep = TRUE, quiet = TRUE)),
    suppressWarnings(.tp_check_jl(deep = TRUE, quiet = TRUE)),
    suppressWarnings(.tp_check_cpp(deep = TRUE, quiet = TRUE))
  )
  worker_rows <- rows[grepl("fresh worker", rows$check, fixed = TRUE), ]
  expect_true(nrow(worker_rows) >= 4L)
  expect_true(all(worker_rows$status == "fail"))
  expect_true(all(grepl("'callr' package is required", worker_rows$detail)))
})

test_that(".tp_check_jl's worker bodies run against a stubbed Julia", {
  skip_if_not_installed("testthat", "3.2.0")
  skip_if_not_installed("JuliaCall")
  # Run the worker body here instead of in a subprocess: that is the only way to exercise the
  # JuliaCall calls themselves (what is passed to julia_setup(), the Pkg.activate() command,
  # the two julia_eval() queries) without a live Julia.
  seen <- list()
  local_mocked_bindings(
    r = function(func, args = list(), ...) do.call(func, args),
    .package = "callr"
  )
  local_mocked_bindings(
    julia_setup = function(...) {
      seen$setup <<- list(...)
      invisible(NULL)
    },
    julia_command = function(cmd, ...) {
      seen$command <<- cmd
      invisible(NULL)
    },
    julia_eval = function(cmd, ...) {
      switch(
        cmd,
        "string(VERSION)" = "1.11.2",
        "Sys.BINDIR" = "/tp/fake/julia/bin",
        "string(pkgversion(Pkg))" = "1.11.0",
        "Base.active_project()" = "/tp/proj/Project.toml",
        ""
      )
    },
    .package = "JuliaCall"
  )
  # A configured julia_home must reach julia_setup() as JULIA_HOME.
  withr::local_options(tarpolyglot.julia_home = "/tp/fake/julia/bin")

  res <- suppressWarnings(.tp_check_jl(deep = FALSE, quiet = TRUE))

  disc <- res[res$check == "Julia interpreter (fresh worker)", ]
  expect_identical(disc$status, "ok")
  expect_match(disc$detail, "/tp/fake/julia/bin (Julia 1.11.2)", fixed = TRUE)

  pkg <- res[res$check == "Pkg (environment manager, fresh worker)", ]
  expect_identical(pkg$status, "ok")
  expect_match(pkg$detail, "Pkg 1.11.0", fixed = TRUE)

  expect_identical(seen$setup$JULIA_HOME, "/tp/fake/julia/bin")
  expect_false(isTRUE(seen$setup$installJulia))
  # Pkg.activate() is handed a raw string, so a Windows path survives it verbatim.
  expect_match(seen$command, "^import Pkg; Pkg\\.activate\\(raw\"")
})

test_that(".tp_check_jl lists the juliaup builds it finds when juliaup is on PATH", {
  skip_if_not_installed("testthat", "3.2.0")
  local_fake_tool("juliaup")
  depot <- withr::local_tempdir()
  for (b in c("julia-1.10.11+0.x64", "julia-1.11.2+0.x64")) {
    dir.create(file.path(depot, "juliaup", b, "bin"), recursive = TRUE)
  }
  withr::local_envvar(JULIA_DEPOT_PATH = depot)
  local_mocked_bindings(
    r = function(...) stop("no julia here"),
    .package = "callr"
  )

  res <- suppressWarnings(.tp_check_jl(deep = FALSE, quiet = TRUE))
  row <- res[res$check == "juliaup", ]
  expect_identical(row$status, "ok")
  expect_match(row$detail, "installed: 1.10.11, 1.11.2", fixed = TRUE)
})

# --------------------------------------------------------------------------
# The C++ compiler check (non-Windows branch)
# --------------------------------------------------------------------------

test_that(".tp_check_cpp warns when R's configured C++ compiler cannot be determined", {
  skip_on_os("windows")
  skip_if_not_installed("testthat", "3.2.0")
  local_mocked_bindings(.tp_cpp_compiler_cmd = function() NA_character_)
  res <- .tp_check_cpp(deep = FALSE, quiet = TRUE)
  row <- res[grepl("^C\\+\\+ compiler", res$check), ]
  expect_identical(row$status, "warn")
  expect_match(row$detail, "R CMD config CXX", fixed = TRUE)
})

test_that(".tp_check_cpp warns, with an install hint, when the compiler is not on PATH", {
  skip_on_os("windows")
  skip_if_not_installed("testthat", "3.2.0")
  local_mocked_bindings(
    .tp_cpp_compiler_cmd = function() "tp-definitely-not-a-compiler-xyz"
  )
  res <- .tp_check_cpp(deep = FALSE, quiet = TRUE)
  row <- res[grepl("^C\\+\\+ compiler", res$check), ]
  expect_identical(row$status, "warn")
  expect_match(row$detail, "not found on PATH", fixed = TRUE)
  expect_match(row$detail, "tp-definitely-not-a-compiler-xyz", fixed = TRUE)
})

test_that(".tp_check_cpp reports a compiler that prints no version", {
  skip_on_os("windows")
  skip_if_not_installed("testthat", "3.2.0")
  local_fake_tool("tp-fake-cxx")
  local_mocked_bindings(.tp_cpp_compiler_cmd = function() "tp-fake-cxx")
  res <- .tp_check_cpp(deep = FALSE, quiet = TRUE)
  row <- res[grepl("^C\\+\\+ compiler", res$check), ]
  expect_identical(row$status, "ok")
  expect_match(row$detail, "tp-fake-cxx", fixed = TRUE)
  expect_false(grepl("()", row$detail, fixed = TRUE))
})

# --------------------------------------------------------------------------
# toolchain_check()'s own summary
# --------------------------------------------------------------------------

test_that("toolchain_check() says so when every check passed", {
  skip_if_not_installed("testthat", "3.2.0")
  local_mocked_bindings(
    .tp_check_cpp = function(deep, quiet) {
      .tp_check_row("cpp", "stub", "ok", "all good")
    }
  )
  expect_message(
    toolchain_check("cpp", deep = FALSE, quiet = FALSE),
    "All checks passed"
  )
})
