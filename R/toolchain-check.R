# toolchain_check(): diagnostics for the Python/Julia/Rust/C++ toolchains
# tar_target_py()/tar_target_jl()/tar_target_rs()/tar_target_cpp() depend on. Every check that
# actually binds an interpreter or compiles code runs inside a throwaway
# callr subprocess, so (a) it never pollutes the caller's own R session (which
# may already have reticulate/JuliaCall bound), and (b) it genuinely answers
# "is this reachable from a fresh crew worker", which is what actually matters
# for a pipeline. PATH-presence checks (Sys.which()) are read-only and run
# directly in the calling session.

.tp_check_row <- function(toolchain, check, status, detail = "") {
  data.frame(
    toolchain = toolchain, check = check, status = status, detail = detail,
    stringsAsFactors = FALSE
  )
}

# Emit cli output for one completed row (a no-op when quiet = TRUE).
.tp_check_report <- function(row, quiet) {
  if (quiet) {
    return(invisible(row))
  }
  msg <- if (nzchar(row$detail)) paste0(row$check, ": ", row$detail) else row$check
  switch(row$status,
    ok = cli::cli_alert_success(msg),
    warn = cli::cli_alert_warning(msg),
    fail = cli::cli_alert_danger(msg),
    cli::cli_alert_info(msg)
  )
  invisible(row)
}

# Run one check: optionally announce it first (pre_msg, for the slower
# checks), catch any error `fn()` raises and turn it into a "fail" row rather
# than aborting the whole toolchain_check() call, then report the result.
.tp_run_check <- function(toolchain, check, quiet, fn, pre_msg = NULL) {
  if (!quiet && !is.null(pre_msg)) cli::cli_alert_info(pre_msg)
  row <- tryCatch(
    fn(),
    error = function(e) .tp_check_row(toolchain, check, "fail", conditionMessage(e))
  )
  .tp_check_report(row, quiet)
  row
}

# A simple `Sys.which()` + `<exe> <version_flag>` presence check, used for
# the environment-manager tools (uv, poetry, conda, rustup, cargo, ...).
.tp_which_check <- function(toolchain, check, exe, version_flag = "--version", quiet = FALSE) {
  row <- tryCatch({
    path <- Sys.which(exe)
    if (nzchar(path)) {
      ver <- tryCatch(
        system2(exe, version_flag, stdout = TRUE, stderr = TRUE),
        error = function(e) character(0), warning = function(w) character(0)
      )
      ver1 <- if (length(ver)) ver[[1]] else ""
      .tp_check_row(toolchain, check, "ok",
                    paste0(path, if (nzchar(ver1)) paste0(" (", ver1, ")") else ""))
    } else {
      .tp_check_row(toolchain, check, "warn", "not found on PATH")
    }
  }, error = function(e) .tp_check_row(toolchain, check, "fail", conditionMessage(e)))
  .tp_check_report(row, quiet)
  row
}

# Report an "installed versions" row from a data.frame(version, path, default)
# built by the language-specific enumerator below. Returns NULL (nothing to
# add to the result) when `versions` is NULL/empty -- e.g. because the
# underlying version manager (uv / juliaup / rustup) is not installed, which
# is already flagged by that tool's own presence check, so no additional
# warning is raised here. With more than one version, this renders as the
# nested bullet list; with exactly one, a single summary line.
.tp_report_versions <- function(toolchain, label, quiet, versions) {
  if (is.null(versions) || nrow(versions) == 0L) {
    return(NULL)
  }
  check <- paste0(label, " versions")
  lines <- sprintf("%s %s%s, %s", label, versions$version,
    ifelse(versions$default, " (default)", ""), versions$path)
  row <- .tp_check_row(toolchain, check, "ok", paste(lines, collapse = "\n"))

  if (!quiet) {
    if (nrow(versions) > 1L) {
      cli::cli_alert_info("Found multiple {label} versions:")
      ul <- cli::cli_ul()
      for (ln in lines) cli::cli_li(ln)
      cli::cli_end(ul)
    } else {
      cli::cli_alert_success(paste0(check, ": ", lines[[1L]]))
    }
  }
  row
}

.tp_require_callr <- function(toolchain, check) {
  if (requireNamespace("callr", quietly = TRUE)) {
    return(NULL)
  }
  .tp_check_row(toolchain, check, "fail", "the 'callr' package is required for this check")
}

# --------------------------------------------------------------------------
# Python
# --------------------------------------------------------------------------

# Enumerate installed Python interpreters via `uv python list --only-installed`
# (uv tracks every CPython it manages, plus any it finds already on the
# machine, e.g. a system install). Only entries with a real path are kept
# (uv also lists versions merely *available to download*, which are not
# "installed"). `resolved_version`/`resolved_path` (the interpreter the
# fresh-worker discovery check above actually resolved) mark the matching row
# as the default -- matched primarily by exact version string, because
# reticulate's default (an *ephemeral* uv-provisioned interpreter, on recent
# reticulate) lives under uv's cache directory, not the "installed" registry
# `--only-installed` lists, so its path never matches even when it is, in
# fact, the very same Python build. Falls back to a path match if the
# version is unavailable. Returns NULL if uv is not on PATH -- nothing to
# enumerate; already flagged by the "uv" presence check.
.tp_python_versions <- function(resolved_version = NULL, resolved_path = NULL) {
  if (!nzchar(Sys.which("uv"))) {
    return(NULL)
  }
  out <- tryCatch(
    system2("uv", c("python", "list", "--only-installed"), stdout = TRUE, stderr = TRUE),
    error = function(e) character(0)
  )
  out <- out[nzchar(trimws(out))]
  if (!length(out)) {
    return(NULL)
  }
  m <- regmatches(out, regexec("^(\\S+)\\s+(\\S+)$", out))
  rows <- Filter(function(x) length(x) == 3L, m)
  if (!length(rows)) {
    return(NULL)
  }
  name <- vapply(rows, `[[`, character(1), 2)
  path <- vapply(rows, `[[`, character(1), 3)
  version <- sub("^cpython-([0-9][0-9a-z.]*)-.*$", "\\1", name)

  default <- if (!is.null(resolved_version) && nzchar(resolved_version)) {
    version == resolved_version
  } else {
    rep(FALSE, length(version))
  }
  if (!any(default) && !is.null(resolved_path) && nzchar(resolved_path)) {
    resolved_norm <- tryCatch(normalizePath(resolved_path, winslash = "/", mustWork = FALSE),
      error = function(e) "")
    path_norm <- vapply(path, function(p) {
      tryCatch(normalizePath(p, winslash = "/", mustWork = FALSE), error = function(e) p)
    }, character(1))
    default <- nzchar(resolved_norm) & tolower(path_norm) == tolower(resolved_norm)
  }

  data.frame(version = version, path = path, default = default, stringsAsFactors = FALSE)
}

.tp_check_py <- function(deep, quiet) {
  check <- "Python interpreter (fresh worker)"
  resolved_python <- NULL
  resolved_version <- NULL
  interp <- .tp_run_check("py", check, quiet,
    pre_msg = "Checking Python interpreter discovery...",
    fn = function() {
      missing <- .tp_require_callr("py", check)
      if (!is.null(missing)) return(missing)
      info <- callr::r(function() {
        cfg <- reticulate::py_config()
        venv_ok <- identical(
          tryCatch(
            system2(cfg$python, c("-m", "venv", "--help"), stdout = FALSE, stderr = FALSE),
            error = function(e) 1L
          ),
          0L
        )
        # cfg$version is only major.minor (e.g. "3.12"); the full patch
        # version is needed to match this interpreter against the
        # `--only-installed` list unambiguously (see .tp_python_versions()).
        full_version <- tryCatch(
          system2(cfg$python,
            c("-c", shQuote("import platform; print(platform.python_version())")),
            stdout = TRUE, stderr = FALSE),
          error = function(e) ""
        )
        list(python = cfg$python, version = as.character(cfg$version),
          full_version = if (length(full_version)) full_version[[1L]] else "",
          venv_ok = venv_ok)
      })
      resolved_python <<- info$python
      resolved_version <<- info$full_version
      .tp_check_row("py", check, "ok", paste0(
        info$python, " (Python ", info$version, "; venv module ",
        if (isTRUE(info$venv_ok)) "available" else "NOT available", ")"
      ))
    }
  )

  uv <- .tp_which_check("py", "uv", "uv", quiet = quiet)
  poetry <- .tp_which_check("py", "poetry", "poetry", quiet = quiet)
  conda <- .tp_which_check("py", "conda", "conda", quiet = quiet)
  versions <- .tp_report_versions("py", "Python", quiet,
    .tp_python_versions(resolved_version, resolved_python))

  rbind(interp, uv, poetry, conda, versions)
}

# --------------------------------------------------------------------------
# Julia
# --------------------------------------------------------------------------

# Enumerate juliaup-installed Julia builds: one row per directory under the
# depot's juliaup/ folder, with the short version (e.g. "1.10.11") and the
# bin/ path -- mirroring the glob `.tp_juliaup_home()` uses to resolve one
# version, but listing all of them instead of resolving a specific one.
# `resolved_version` (the version the fresh-worker discovery check actually
# reported) marks the matching row as the default. Returns NULL if there is
# no juliaup depot to enumerate.
.tp_juliaup_installed <- function(resolved_version = NULL) {
  depot <- Sys.getenv("JULIA_DEPOT_PATH", unset = file.path(.tp_user_home(), ".julia"))
  depot <- strsplit(depot, .Platform$path.sep, fixed = TRUE)[[1]][1]
  hits <- Sys.glob(file.path(depot, "juliaup", "julia-*", "bin"))
  if (!length(hits)) {
    return(NULL)
  }
  build <- sub("^julia-", "", basename(dirname(hits)))
  short <- sub("\\+.*$", "", build)
  data.frame(
    version = short, path = hits,
    default = if (!is.null(resolved_version) && nzchar(resolved_version)) {
      short == resolved_version
    } else {
      FALSE
    },
    stringsAsFactors = FALSE
  )
}

.tp_check_jl <- function(deep, quiet) {
  juliaup <- .tp_run_check("jl", "juliaup", quiet, fn = function() {
    path <- Sys.which("juliaup")
    if (!nzchar(path)) {
      return(.tp_check_row("jl", "juliaup", "warn",
        "not found on PATH (Julia discovery will rely on the system Julia instead)"))
    }
    installed <- .tp_juliaup_installed()
    detail <- if (!is.null(installed)) {
      paste0(path, " (installed: ", toString(installed$version), ")")
    } else {
      paste0(path, " (no versions installed)")
    }
    .tp_check_row("jl", "juliaup", "ok", detail)
  })

  check <- "Julia interpreter (fresh worker)"
  resolved_version <- NULL
  discovery <- .tp_run_check("jl", check, quiet,
    pre_msg = "Checking Julia discovery and version...",
    fn = function() {
      missing <- .tp_require_callr("jl", check)
      if (!is.null(missing)) return(missing)
      julia_home <- getOption("tarpolyglot.julia_home")
      info <- callr::r(function(julia_home) {
        args <- list(installJulia = FALSE, verbose = FALSE)
        if (!is.null(julia_home) && nzchar(julia_home)) args$JULIA_HOME <- julia_home
        do.call(JuliaCall::julia_setup, args)
        list(
          version = JuliaCall::julia_eval("string(VERSION)"),
          bindir = JuliaCall::julia_eval("Sys.BINDIR")
        )
      }, args = list(julia_home = julia_home))
      resolved_version <<- info$version
      .tp_check_row("jl", check, "ok", paste0(info$bindir, " (Julia ", info$version, ")"))
    }
  )

  versions <- .tp_report_versions("jl", "Julia", quiet, .tp_juliaup_installed(resolved_version))

  # Julia's actual analogue of a Python virtualenv/uv/poetry environment is
  # not a separate tool: it is the Pkg *project environment* mechanism built
  # into Julia itself (a folder with Project.toml/Manifest.toml, activated
  # with Pkg.activate()) -- exactly what `julia_project`/`julia_packages`
  # drive in tar_target_jl() (see .tp_resolve_julia() in julia-helpers.R).
  # juliaup, checked above, only manages Julia *versions*; this checks that
  # the environment-manager mechanism itself actually works.
  check2 <- "Pkg (environment manager, fresh worker)"
  pkg_env <- .tp_run_check("jl", check2, quiet,
    pre_msg = "Checking Julia's Pkg project-environment mechanism...",
    fn = function() {
      missing <- .tp_require_callr("jl", check2)
      if (!is.null(missing)) return(missing)
      julia_home <- getOption("tarpolyglot.julia_home")
      info <- callr::r(function(julia_home) {
        args <- list(installJulia = FALSE, verbose = FALSE)
        if (!is.null(julia_home) && nzchar(julia_home)) args$JULIA_HOME <- julia_home
        do.call(JuliaCall::julia_setup, args)
        tmp <- tempfile("tp_diag_env")
        dir.create(tmp)
        # Same call shape .tp_resolve_julia() uses for a real `julia_project`.
        JuliaCall::julia_command(sprintf('import Pkg; Pkg.activate(raw"%s")', tmp))
        list(
          pkg_version = JuliaCall::julia_eval("string(pkgversion(Pkg))"),
          active_project = JuliaCall::julia_eval("Base.active_project()")
        )
      }, args = list(julia_home = julia_home))
      ok <- is.character(info$active_project) && nzchar(info$active_project)
      if (ok) {
        .tp_check_row("jl", check2, "ok",
          paste0("Pkg ", info$pkg_version, "; Pkg.activate() into a fresh project succeeded"))
      } else {
        .tp_check_row("jl", check2, "fail", "Pkg.activate() did not report an active project")
      }
    }
  )

  rbind(juliaup, discovery, versions, pkg_env)
}

# --------------------------------------------------------------------------
# Rust
# --------------------------------------------------------------------------

# Enumerate rustup-installed toolchains via `rustup toolchain list -v`
# (unlike Python/Julia, rustup itself marks the default inline as
# "(default)" -- or "(active, default)" for the one active in the current
# directory -- so there is no need to cross-reference a separately-resolved
# version). Returns NULL if rustup is not on PATH.
.tp_rust_toolchains <- function() {
  if (!nzchar(Sys.which("rustup"))) {
    return(NULL)
  }
  out <- tryCatch(
    system2("rustup", c("toolchain", "list", "-v"), stdout = TRUE, stderr = TRUE),
    error = function(e) character(0)
  )
  out <- out[nzchar(trimws(out))]
  if (!length(out)) {
    return(NULL)
  }
  m <- regmatches(out, regexec("^(\\S+(?:\\s+\\([^)]*\\))?)\\s+(\\S+)$", out, perl = TRUE))
  rows <- Filter(function(x) length(x) == 3L, m)
  if (!length(rows)) {
    return(NULL)
  }
  raw_name <- vapply(rows, `[[`, character(1), 2)
  path <- vapply(rows, `[[`, character(1), 3)
  data.frame(
    version = trimws(sub("\\s*\\([^)]*\\)\\s*$", "", raw_name)),
    path = path,
    default = grepl("default", raw_name, fixed = TRUE),
    stringsAsFactors = FALSE
  )
}

.tp_check_rs <- function(deep, quiet) {
  rustup <- .tp_run_check("rs", "rustup", quiet, fn = function() {
    path <- Sys.which("rustup")
    if (!nzchar(path)) return(.tp_check_row("rs", "rustup", "warn", "not found on PATH"))
    active <- tryCatch(
      system2("rustup", c("show", "active-toolchain"), stdout = TRUE, stderr = TRUE),
      error = function(e) character(0)
    )
    .tp_check_row("rs", "rustup", "ok",
      paste0(path, if (length(active)) paste0(" (active: ", active[[1]], ")") else ""))
  })

  cargo <- .tp_which_check("rs", "cargo", "cargo", quiet = quiet)
  versions <- .tp_report_versions("rs", "Rust toolchain", quiet, .tp_rust_toolchains())

  rows <- list(rustup = rustup, cargo = cargo, versions = versions)

  if (.Platform$OS.type == "windows") {
    rows$gnu <- .tp_run_check("rs", "GNU toolchain (Windows)", quiet, fn = function() {
      out <- tryCatch(
        system2("rustup", c("toolchain", "list"), stdout = TRUE, stderr = TRUE),
        error = function(e) character(0)
      )
      gnu <- grep("gnu", out, fixed = TRUE, value = TRUE)
      if (length(gnu)) {
        .tp_check_row("rs", "GNU toolchain (Windows)", "ok", paste(gnu, collapse = "; "))
      } else {
        .tp_check_row("rs", "GNU toolchain (Windows)", "fail", paste0(
          "no *-gnu toolchain installed; rextendr needs it to match R's mingw ABI. ",
          "Install with: rustup toolchain install stable-x86_64-pc-windows-gnu"))
      }
    })

    rows$rtools <- .tp_run_check("rs", "Rtools (Windows)", quiet, fn = function() {
      rt <- Sys.getenv("RTOOLS45_HOME", unset = "")
      candidates <- c(if (nzchar(rt)) file.path(rt, "usr", "bin"),
                       "C:/rtools45/usr/bin", "C:/rtools44/usr/bin")
      found <- candidates[dir.exists(candidates)]
      if (length(found)) {
        .tp_check_row("rs", "Rtools (Windows)", "ok", found[[1]])
      } else {
        .tp_check_row("rs", "Rtools (Windows)", "warn",
          "not found under RTOOLS45_HOME or the default install paths (C:/rtools45, C:/rtools44)")
      }
    })
  }

  if (isTRUE(deep)) {
    check <- "Compile reachability (fresh worker)"
    rows$compile <- .tp_run_check("rs", check, quiet,
      pre_msg = "Compiling a trivial Rust function to test full reachability (can take up to a minute)...",
      fn = function() {
        missing <- .tp_require_callr("rs", check)
        if (!is.null(missing)) return(missing)
        t0 <- Sys.time()
        val <- callr::r(function() {
          restore <- .tp_with_rust_build_env()
          on.exit(restore(), add = TRUE)
          e <- new.env()
          rextendr::rust_source(
            code = "#[extendr] fn tp_diag_ping(x: f64) -> f64 { x + 1.0 }",
            env = e, quiet = TRUE
          )
          e$tp_diag_ping(1)
        }, package = "tarpolyglot")
        secs <- round(as.numeric(Sys.time() - t0, units = "secs"), 1)
        if (isTRUE(all.equal(val, 2))) {
          .tp_check_row("rs", check, "ok", paste0("compiled and ran successfully in ", secs, "s"))
        } else {
          .tp_check_row("rs", check, "fail", paste0("unexpected result: ", val))
        }
      }
    )
  }

  do.call(rbind, rows)
}

# --------------------------------------------------------------------------
# C++
# --------------------------------------------------------------------------

# The C++ compiler command R itself is configured to use for R CMD SHLIB,
# i.e. exactly what Rcpp::sourceCpp() invokes -- queried via `R CMD config
# CXX` rather than guessed from the OS (g++ on Linux, clang++ on macOS, ...),
# so this is correct even on a machine where R was configured to use a
# non-default compiler. Returns NA if the query itself fails. CXX may in
# principle include flags after the executable name; only the first token
# (the executable) is kept, since that is what Sys.which() needs.
.tp_cpp_compiler_cmd <- function() {
  out <- tryCatch(
    system2(file.path(R.home("bin"), "R"), c("CMD", "config", "CXX"),
      stdout = TRUE, stderr = TRUE),
    error = function(e) character(0)
  )
  out <- trimws(out)
  out <- out[nzchar(out)]
  if (!length(out)) {
    return(NA_character_)
  }
  strsplit(out[[1]], "\\s+")[[1]][1]
}

# Presence check for Rcpp itself, the only C++ dependency tarpolyglot
# actually needs. Extension packages such as RcppArmadillo, RcppEigen, and
# RcppParallel are entirely the caller's choice (passed via `depends`, or
# declared directly in the C++ source): tarpolyglot itself does not depend on
# any of them, so checking their presence here would be no more meaningful
# than checking any other CRAN package a user's script might happen to use.
.tp_check_cpp <- function(deep, quiet) {
  rows <- list()
  rows$Rcpp <- .tp_run_check("cpp", "Rcpp", quiet, fn = function() {
    if (requireNamespace("Rcpp", quietly = TRUE)) {
      .tp_check_row("cpp", "Rcpp", "ok", as.character(utils::packageVersion("Rcpp")))
    } else {
      .tp_check_row("cpp", "Rcpp", "fail", "not installed (required for tar_target_cpp())")
    }
  })

  if (.Platform$OS.type == "windows") {
    rows$rtools <- .tp_run_check("cpp", "Rtools (Windows)", quiet, fn = function() {
      rt <- Sys.getenv("RTOOLS45_HOME", unset = "")
      candidates <- c(if (nzchar(rt)) file.path(rt, "usr", "bin"),
                       "C:/rtools45/usr/bin", "C:/rtools44/usr/bin")
      found <- candidates[dir.exists(candidates)]
      if (length(found)) {
        .tp_check_row("cpp", "Rtools (Windows)", "ok", found[[1]])
      } else {
        .tp_check_row("cpp", "Rtools (Windows)", "warn",
          "not found under RTOOLS45_HOME or the default install paths (C:/rtools45, C:/rtools44)")
      }
    })
  } else {
    os_label <- if (identical(Sys.info()[["sysname"]], "Darwin")) "macOS" else "Linux"
    check <- paste0("C++ compiler (", os_label, ")")
    rows$compiler <- .tp_run_check("cpp", check, quiet, fn = function() {
      # The compiler R itself is configured to use for R CMD SHLIB, the same
      # one sourceCpp() invokes -- queried rather than guessed by OS, so this
      # is correct whether the machine uses gcc or clang under the hood.
      cxx <- .tp_cpp_compiler_cmd()
      if (is.na(cxx)) {
        return(.tp_check_row("cpp", check, "warn",
          "could not determine R's configured C++ compiler (R CMD config CXX)"))
      }
      path <- Sys.which(cxx)
      if (!nzchar(path)) {
        hint <- if (identical(os_label, "macOS")) {
          paste0(cxx, " not found on PATH; install Xcode's command line tools (xcode-select --install)")
        } else {
          paste0(cxx, " not found on PATH; install a C++ compiler and R's own development ",
            "package (e.g. r-base-dev on Debian/Ubuntu, R-devel on Fedora)")
        }
        return(.tp_check_row("cpp", check, "warn", hint))
      }
      ver <- tryCatch(system2(cxx, "--version", stdout = TRUE, stderr = TRUE),
        error = function(e) character(0))
      ver1 <- if (length(ver)) ver[[1]] else ""
      .tp_check_row("cpp", check, "ok",
        paste0(path, if (nzchar(ver1)) paste0(" (", ver1, ")") else ""))
    })
  }

  if (isTRUE(deep)) {
    check <- "Compile reachability (fresh worker)"
    rows$compile <- .tp_run_check("cpp", check, quiet,
      pre_msg = "Compiling a trivial C++ function to test full reachability...",
      fn = function() {
        missing <- .tp_require_callr("cpp", check)
        if (!is.null(missing)) return(missing)
        t0 <- Sys.time()
        val <- callr::r(function() {
          restore <- .tp_with_cpp_build_env()
          on.exit(restore(), add = TRUE)
          e <- new.env()
          Rcpp::sourceCpp(code = paste(
            "#include <Rcpp.h>",
            "// [[Rcpp::export]]",
            "double tp_diag_ping(double x) { return x + 1.0; }",
            sep = "\n"
          ), env = e, verbose = FALSE)
          e$tp_diag_ping(1)
        }, package = "tarpolyglot")
        secs <- round(as.numeric(Sys.time() - t0, units = "secs"), 1)
        if (isTRUE(all.equal(val, 2))) {
          .tp_check_row("cpp", check, "ok", paste0("compiled and ran successfully in ", secs, "s"))
        } else {
          .tp_check_row("cpp", check, "fail", paste0("unexpected result: ", val))
        }
      }
    )
  }

  do.call(rbind, rows)
}

#' Diagnose the Python, Julia, Rust, and C++ toolchains
#'
#' Runs a battery of checks for whichever toolchains you ask for and reports the result with [cli](https://cli.r-lib.org/) as it goes: interpreter/compiler discovery, environment-manager availability, and, most importantly, whether each toolchain is actually *reachable from a fresh worker process* -- the same kind of process `crew` spawns to run a `tar_target_py()`/`tar_target_jl()`/`tar_target_rs()` step. This is meant to preempt the common "it doesn't run on my machine" class of issue before you find out the hard way, mid-pipeline.
#'
#' Environment managers checked per language: for Python, `uv`, `poetry`, and `conda` (three separate, competing tools, plus the stdlib `venv` module on the resolved interpreter). For Julia, `juliaup` (which manages *versions*, checked via presence + the list of installed versions) and, separately, Julia's own `Pkg` project-environment mechanism (which manages *packages*, activated with `Pkg.activate()` -- the actual mechanism behind `julia_project`/`julia_packages`): a fresh worker actually activates a throwaway project to prove it works, not just that Julia is present. Rust has no separate environment concept (see `vignette("rust")`); `rustup`/`cargo`/(on Windows) the GNU toolchain and Rtools are checked instead.
#'
#' Every check that would bind an interpreter (Python, Julia) or compile code (Rust, C++) runs inside a disposable [callr::r()] subprocess, never in your current R session: this means `toolchain_check()` cannot leave reticulate or JuliaCall bound afterwards, and it is answering the *real* question ("would a crew worker be able to do this right now"), not just "is something already loaded in this session". Plain presence checks (`Sys.which()` for `uv`, `poetry`, `rustup`, and so on, or `requireNamespace()` for Rcpp) run directly, since they have no side effects to isolate.
#'
#' When more than one version is found, each language also reports every installed version it can enumerate, with its path and which one is the default (the one a step would actually use if you set nothing): Python via `uv python list --only-installed` (matched against the resolved interpreter primarily by exact version, since reticulate's default is often an *ephemeral* uv-provisioned interpreter that lives under uv's cache rather than its "installed" registry, so the two rarely share a literal path even when they are, in fact, the same build); Julia via the juliaup depot; Rust via `rustup toolchain list -v` (which marks its own default inline, no cross-referencing needed). With only one version found, this is a single summary line instead. C++ has no separate version-manager concept to enumerate this way (see `tar_target_cpp()`): it compiles via R's own configured toolchain, so its checks are presence (Rcpp; the OS-appropriate compiler, Rtools on Windows or the actual `R CMD config CXX` compiler command on macOS/Linux, queried rather than guessed so it is correct under gcc or clang alike) plus, with `deep = TRUE`, a compile-reachability check. Extension packages such as RcppArmadillo/RcppEigen/RcppParallel are not checked here since tarpolyglot itself does not depend on any of them; they are entirely the caller's own choice via `depends` (see `tar_target_cpp()`).
#'
#' @param toolchains Character vector, which toolchains to check: any subset of `"py"`, `"jl"`, `"rs"`, `"cpp"`. Default checks all four.
#' @param deep Logical. When `TRUE` (the default), the Rust and C++ checks additionally compile a trivial function (`#[extendr]` / `// [[Rcpp::export]]`) in a fresh worker to prove the full toolchain actually links together end to end; this is the most informative check for each but also the slowest (well under a minute, but not instant). Set `deep = FALSE` to skip it and rely on the faster presence checks alone. Python and Julia's fresh-worker checks are cheap either way and always run.
#' @param quiet Logical, default `FALSE`. Suppress the live `cli` progress/result output; the return value is unaffected either way.
#'
#' @return Invisibly, a `data.frame` with one row per check and columns `toolchain` (`"py"`/`"jl"`/`"rs"`/`"cpp"`), `check` (a short label), `status` (`"ok"`, `"warn"`, or `"fail"`), and `detail` (a human-readable description, e.g. the resolved path and version, or an error message).
#' @seealso [tar_target_py()], [tar_target_jl()], [tar_target_rs()], [tar_target_cpp()]
#' @examples
#' # Every check runs in a fresh callr subprocess, and with deep = TRUE it also
#' # compiles a trivial function, so this is gated on TARPOLYGLOT_EXAMPLES=true
#' # rather than run on machines with no toolchain installed.
#' if (identical(Sys.getenv("TARPOLYGLOT_EXAMPLES"), "true")) {
#'   toolchain_check("py")                  # Python only
#'   toolchain_check(c("jl", "rs"))         # Julia and Rust
#'   toolchain_check("rs", deep = FALSE)    # skip the Rust compile test
#'
#'   res <- toolchain_check(quiet = TRUE)   # no console output, just the data.frame
#'   res[res$status != "ok", ]              # anything that needs attention
#' }
#' @export
toolchain_check <- function(toolchains = c("py", "jl", "rs", "cpp"), deep = TRUE, quiet = FALSE) {
  # match.arg(..., several.ok = TRUE) silently DROPS unrecognised values
  # instead of erroring, so it is validated by hand here.
  choices <- c("py", "jl", "rs", "cpp")
  bad <- setdiff(toolchains, choices)
  if (length(bad)) {
    stop("`toolchains` must be a subset of ", toString(shQuote(choices)),
      "; got unrecognised value", if (length(bad) > 1L) "s" else "", ": ",
      toString(shQuote(bad)), call. = FALSE)
  }
  toolchains <- unique(toolchains)
  # Used below inside a cli glue string ("{labels[[tc]]} toolchain"), which
  # codetools does not parse.
  labels <- c(py = "Python", jl = "Julia", rs = "Rust", cpp = "C++")

  all_rows <- list()
  for (tc in toolchains) {
    if (!quiet) cli::cli_h2("{labels[[tc]]} toolchain")
    all_rows[[tc]] <- switch(tc,
      py = .tp_check_py(deep = deep, quiet = quiet),
      jl = .tp_check_jl(deep = deep, quiet = quiet),
      rs = .tp_check_rs(deep = deep, quiet = quiet),
      cpp = .tp_check_cpp(deep = deep, quiet = quiet)
    )
  }

  result <- do.call(rbind, all_rows)
  rownames(result) <- NULL

  if (!quiet) {
    n_fail <- sum(result$status == "fail")
    n_warn <- sum(result$status == "warn")
    cli::cli_h2("Summary")
    if (n_fail == 0L && n_warn == 0L) {
      cli::cli_alert_success("All checks passed.")
    } else {
      cli::cli_alert_info(
        "{n_fail} failed, {n_warn} warning{?s}, out of {nrow(result)} checks."
      )
    }
  }

  invisible(result)
}
