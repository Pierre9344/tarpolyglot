# Per-process record of which compiled library (by content) is currently loaded
# under each rextendr module name (e.g. "rextendr1"), so run_rs_step_prebuilt()
# can reuse it when the same library repeats and hot-swap it when a different one
# needs the same name. See run_rs_step_prebuilt().
.tp_rustlib_loaded <- new.env(parent = emptyenv())

# Rust step worker (extendr model). Unlike the subprocess approach, this compiles the Rust `#[extendr]` functions in `script` with rextendr::rust_source() and exposes them as R functions in the step environment; a post-R script then calls those functions (with the upstream `inputs` bound alongside) and returns the target value. There is no pre-R script for Rust: inputs are used directly from the post-script.
#
# Windows note: rextendr requires the Rust GNU toolchain (to match R's mingw ABI). Set it as the rustup default, or pass `toolchain = "stable-x86_64-pc-windows-gnu"` (which sets RUSTUP_TOOLCHAIN for the build).

# extendr's build script must find R (for R_HOME and version) and the toolchain (cargo, and on Windows the Rtools linker). Bare non-interactive R sessions and crew workers often don't have these on PATH, so we set them up best-effort for the build and restore afterwards. Returns a zero-arg restore function.
.tp_with_rust_build_env <- function() {
  old_rhome <- Sys.getenv("R_HOME", unset = NA)
  old_path <- Sys.getenv("PATH")
  restore <- function() {
    if (is.na(old_rhome)) Sys.unsetenv("R_HOME") else Sys.setenv(R_HOME = old_rhome)
    Sys.setenv(PATH = old_path)
  }

  if (is.na(old_rhome) || !nzchar(old_rhome)) Sys.setenv(R_HOME = R.home())

  add <- c(R.home("bin"), file.path(R.home("bin"), "x64"))
  cargo <- file.path(.tp_user_home(), ".cargo", "bin")
  add <- c(add, cargo)
  if (.Platform$OS.type == "windows") {
    rt <- Sys.getenv("RTOOLS45_HOME", unset = "")
    for (d in c(if (nzchar(rt)) file.path(rt, "usr", "bin"),
                "C:/rtools45/usr/bin", "C:/rtools44/usr/bin")) {
      if (dir.exists(d)) { add <- c(add, d); break }
    }
  }
  add <- add[dir.exists(add)]
  if (length(add)) {
    Sys.setenv(PATH = paste(c(add, old_path), collapse = .Platform$path.sep))
  }
  restore
}

#' Execute a Rust step (worker behind tar_target_rs)
#'
#' Compiles the `#[extendr]` functions in a Rust script with [rextendr::rust_source()], exposing them as R functions in a fresh environment, then evaluates an R **post-script** in that environment where you call those functions and return the result. Upstream `inputs` are bound in the same environment. This is the function the target built by [tar_target_rs()] calls; it is exported so the call resolves at run time, but package users should not call it directly.
#'
#' Unlike Python/Julia there is **no pre-script** for Rust and no live interpreter: `rust_source()` compiles a dynamic library and R calls into it with real type conversion (via [extendr](https://extendr.rs/)). A Rust toolchain and `cargo` must be reachable (this function puts R, cargo, and on Windows Rtools on `PATH` for the build itself); on Windows use the GNU toolchain.
#'
#' @inheritParams tarpolyglot-shared-params
#' @inheritSection tarpolyglot-shared-params Script arguments
#' @param script Path to the Rust script containing `#[extendr]` functions (required). Accepts a file path or an inline [tar_code()] carrier; see the "Script arguments" section below.
#' @param post_script Path to an R script evaluated after compilation. The compiled Rust functions and the named `inputs` are in scope; its last expression is the target value (object mode), or it returns a character vector of file paths (file mode). Required for object mode. Accepts a file path or an inline [tar_code()] carrier; see the "Script arguments" section below.
#' @param dependencies,features,profile Passed to [rextendr::rust_source()]: crate `dependencies` (named list), Cargo `features`, and build `profile` (e.g. `"dev"` or `"release"`).
#' @param toolchain Optional rustup toolchain (e.g. `"stable-x86_64-pc-windows-gnu"`); sets `RUSTUP_TOOLCHAIN` for the build. Default `NULL` uses the rustup default toolchain.
#'
#' @return The value of the post-script (object mode) or a character vector of normalised file paths (file mode).
#' @seealso [tar_target_rs()], [run_py_step()], [run_jl_step()]
#' @export
#' @examples
#' \dontrun{
#' # Normally invoked by tar_target_rs(); shown here as a direct call.
#' # scripts/square.rs:
#' #   #[extendr]
#' #   fn square(x: f64) -> f64 { x * x }
#' # scripts/post.R:
#' #   square(x)
#' run_rs_step(
#'   script = "scripts/square.rs",
#'   inputs = list(x = 21),
#'   post_script = "scripts/post.R"
#' )
#' }
run_rs_step <- function(script,
                        post_script = NULL,
                        inputs = list(),
                        output = "object",
                        files = NULL,
                        dependencies = NULL,
                        features = NULL,
                        profile = NULL,
                        toolchain = NULL) {
  output <- .tp_match_output(output)
  .tp_assert_script(script, "script", must_exist = TRUE)

  e <- new.env(parent = globalenv())
  for (nm in names(inputs)) assign(nm, inputs[[nm]], envir = e)

  # Make sure the extendr build can find R and the toolchain (restored after).
  restore_env <- .tp_with_rust_build_env()
  on.exit(restore_env(), add = TRUE)

  # Optional per-build toolchain (restored afterwards).
  if (!is.null(toolchain)) {
    old_tc <- Sys.getenv("RUSTUP_TOOLCHAIN", unset = NA)
    Sys.setenv(RUSTUP_TOOLCHAIN = as.character(toolchain))
    on.exit({
      if (is.na(old_tc)) Sys.unsetenv("RUSTUP_TOOLCHAIN") else
        Sys.setenv(RUSTUP_TOOLCHAIN = old_tc)
    }, add = TRUE)
  }

  # 1. Compile the #[extendr] functions and expose them in `e`. We pass the Rust as `code=` (rextendr's `file=` path does not wrap the module / wrapper generator the way `code=` does), so a plain script of `#[extendr]` functions works and the extendr prelude is added for you. The source is either read from the script file or supplied inline via tar_code().
  code <- if (inherits(script, "tp_source")) script$code else
    paste(readLines(script, warn = FALSE), collapse = "\n")
  args <- list(code = code, env = e, quiet = TRUE)
  if (!is.null(dependencies)) args$dependencies <- dependencies
  if (!is.null(features)) args$features <- features
  if (!is.null(profile)) args$profile <- profile
  do.call(rextendr::rust_source, args)

  # 2. Post-R script uses the compiled functions (and inputs) to build the value.
  .tp_rs_finish(e, post_script, output, files)
}

# Shared tail of the Rust workers: with the compiled functions and `inputs`
# already bound in `e`, evaluate the R post-script and produce the target value
# (object mode) or a character vector of normalised file paths (file mode).
.tp_rs_finish <- function(e, post_script, output, files) {
  if (identical(output, "file")) {
    paths <- if (!is.null(post_script)) {
      .tp_assert_script(post_script, "post_script", must_exist = TRUE)
      .tp_eval_script(post_script, e)
    } else {
      files
    }
    if (is.null(paths)) {
      stop("output = \"file\" needs a `post_script` returning paths, or `files`.",
        call. = FALSE)
    }
    return(normalizePath(as.character(paths), winslash = "/", mustWork = FALSE))
  }

  if (is.null(post_script)) {
    stop("output = \"object\" needs a `post_script` that calls the compiled Rust ",
      "function(s) and returns a value.", call. = FALSE)
  }
  .tp_assert_script(post_script, "post_script", must_exist = TRUE)
  .tp_eval_script(post_script, e)
}

#' Compile a Rust step once for reuse across branches (worker behind tarpolyglot_map)
#'
#' Compiles the `#[extendr]` functions in a Rust script with [rextendr::rust_source()] and returns a self-contained bundle (the compiled shared library plus its generated R wrappers) that [run_rs_step_prebuilt()] can reload in any branch without recompiling. This is the function the companion `<name>_rust_lib` target built by `tar_target_rs(..., pattern = tarpolyglot_map(...))` calls; it is exported so the call resolves at run time, but package users should not call it directly.
#'
#' The bundle embeds the library bytes, so it travels with the target's value to any worker or machine, and reloading is a `dyn.load()` (near-instant) rather than a fresh `cargo` build. See [tarpolyglot_map()] for the motivation and [run_rs_step()] for the per-branch (recompiling) alternative.
#'
#' @inheritParams run_rs_step
#' @inheritSection tarpolyglot-shared-params Script arguments
#'
#' @return An object of class `tp_rust_lib`: a list with the library `basename`, the raw library `bytes`, and the generated wrapper `objs` (named list of R functions).
#' @seealso [tarpolyglot_map()], [run_rs_step_prebuilt()], [tar_target_rs()]
#' @keywords internal
#' @export
#' @examples
#' \dontrun{
#' # Normally invoked by tar_target_rs(pattern = tarpolyglot_map(...)).
#' # scripts/square.rs:
#' #   #[extendr]
#' #   fn square(x: f64) -> f64 { x * x }
#' lib <- compile_rs_lib(script = "scripts/square.rs")
#' }
compile_rs_lib <- function(script,
                           dependencies = NULL,
                           features = NULL,
                           profile = NULL,
                           toolchain = NULL) {
  .tp_assert_script(script, "script", must_exist = TRUE)

  restore_env <- .tp_with_rust_build_env()
  on.exit(restore_env(), add = TRUE)

  if (!is.null(toolchain)) {
    old_tc <- Sys.getenv("RUSTUP_TOOLCHAIN", unset = NA)
    Sys.setenv(RUSTUP_TOOLCHAIN = as.character(toolchain))
    on.exit({
      if (is.na(old_tc)) Sys.unsetenv("RUSTUP_TOOLCHAIN") else
        Sys.setenv(RUSTUP_TOOLCHAIN = old_tc)
    }, add = TRUE)
  }

  code <- if (inherits(script, "tp_source")) script$code else
    paste(readLines(script, warn = FALSE), collapse = "\n")

  # Note which DLLs are already loaded, so we can single out the one rust_source
  # is about to build (its path is a fresh temp file).
  loaded_before <- vapply(getLoadedDLLs(), function(d) d[["path"]], character(1))

  e <- new.env(parent = globalenv())
  args <- list(code = code, env = e, quiet = TRUE)
  if (!is.null(dependencies)) args$dependencies <- dependencies
  if (!is.null(features)) args$features <- features
  if (!is.null(profile)) args$profile <- profile
  do.call(rextendr::rust_source, args)

  # Locate the freshly compiled extendr library. rextendr names it `rextendr<N>`
  # (registered DLL name and file basename), and the generated wrappers call it
  # via `.Call(..., PACKAGE = "rextendr<N>")`, so reproducing this exact basename
  # on reload is what makes those wrappers resolve.
  info <- getLoadedDLLs()
  paths <- vapply(info, function(d) d[["path"]], character(1))
  dnames <- vapply(info, function(d) d[["name"]], character(1))
  is_extendr <- (grepl("^rextendr[0-9]+$", dnames) |
    grepl("^(lib)?rextendr[0-9]+\\.(dll|so|dylib)$", basename(paths))) &
    !(paths %in% loaded_before)
  hits <- which(is_extendr)
  if (!length(hits)) {
    stop("Could not locate the compiled extendr library after rust_source().",
      call. = FALSE)
  }
  dll_path <- paths[[hits[length(hits)]]]

  bytes <- readBin(dll_path, what = "raw", n = file.info(dll_path)$size)
  objs <- stats::setNames(lapply(ls(e), function(n) get(n, envir = e)), ls(e))

  structure(
    list(basename = basename(dll_path), bytes = bytes, objs = objs),
    class = "tp_rust_lib"
  )
}

#' Run a Rust step from a pre-compiled library (worker behind tarpolyglot_map)
#'
#' Reloads a compiled Rust library produced by [compile_rs_lib()] (writing the embedded shared library to a temporary file and `dyn.load()`-ing it, then binding the generated wrapper functions), then evaluates the R **post-script** exactly as [run_rs_step()] does, with the compiled functions and the named `inputs` in scope. This is the function each branch target built by `tar_target_rs(..., pattern = tarpolyglot_map(...))` calls; it is exported so the call resolves at run time, but package users should not call it directly.
#'
#' No Rust toolchain is needed here: reloading is a `dyn.load()`, not a build. See [tarpolyglot_map()] for the overall design.
#'
#' @inheritParams run_rs_step
#' @inheritSection tarpolyglot-shared-params Script arguments
#' @param lib A `tp_rust_lib` bundle from [compile_rs_lib()] (supplied by the companion `<name>_rust_lib` target).
#'
#' @return The value of the post-script (object mode) or a character vector of normalised file paths (file mode).
#' @seealso [tarpolyglot_map()], [compile_rs_lib()], [run_rs_step()]
#' @keywords internal
#' @export
#' @examples
#' \dontrun{
#' # Normally invoked by tar_target_rs(pattern = tarpolyglot_map(...)).
#' # scripts/square.rs:
#' #   #[extendr]
#' #   fn square(x: f64) -> f64 { x * x }
#' # scripts/post.R:
#' #   square(x)
#' lib <- compile_rs_lib(script = "scripts/square.rs")
#' run_rs_step_prebuilt(lib = lib, inputs = list(x = 21), post_script = "scripts/post.R")
#' }
run_rs_step_prebuilt <- function(lib,
                                 post_script = NULL,
                                 inputs = list(),
                                 output = "object",
                                 files = NULL) {
  output <- .tp_match_output(output)
  if (!inherits(lib, "tp_rust_lib")) {
    stop("`lib` must be a compiled library object from compile_rs_lib().",
      call. = FALSE)
  }

  # Materialise the embedded library and dyn.load it so its wrappers resolve. Its
  # generated wrappers call `.Call(..., PACKAGE = "rextendr<N>")`, and the file
  # basename must match that module name for the call to resolve, so we cannot
  # simply rename the library to something unique. rextendr numbers each freshly
  # compiled crate `rextendr<N>` from a per-process counter, so two different
  # compile-once targets built in separate workers can both be `rextendr1`. R
  # keys loaded DLLs by that name, so loading a second one under the same name
  # would be ignored (the first would shadow it). We therefore track which
  # library (by content) is loaded under each module name and hot-swap when a
  # different one arrives, while reusing it when the same library repeats: the
  # common case of many branches of one target on one worker stays a no-op.
  regname <- tools::file_path_sans_ext(lib$basename)
  if (!identical(.tp_rustlib_loaded[[regname]], lib$bytes)) {
    loaded <- getLoadedDLLs()
    if (regname %in% names(loaded)) {
      try(dyn.unload(loaded[[regname]][["path"]]), silent = TRUE)
    }
    base <- file.path(tempdir(), "tarpolyglot-rustlib")
    dir.create(base, showWarnings = FALSE, recursive = TRUE)
    # Write into a fresh unique subdirectory rather than overwriting a fixed file:
    # on Windows the previous copy may still be locked (it was just loaded, and an
    # antivirus scanner may hold it), which fails an overwrite. The basename is
    # kept because it must match the compiled module name for the wrappers to
    # resolve.
    sub <- tempfile("lib", tmpdir = base)
    dir.create(sub)
    path <- file.path(sub, lib$basename)
    writeBin(lib$bytes, path)
    dyn.load(path, local = TRUE, now = TRUE)
    .tp_rustlib_loaded[[regname]] <- lib$bytes
  }

  e <- new.env(parent = globalenv())
  for (nm in names(inputs)) assign(nm, inputs[[nm]], envir = e)
  for (nm in names(lib$objs)) assign(nm, lib$objs[[nm]], envir = e)

  .tp_rs_finish(e, post_script, output, files)
}
