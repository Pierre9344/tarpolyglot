# Configure the JuliaCall / Julia binding for the current R session. Like reticulate, JuliaCall binds a single Julia per session, so this runs once at the start of each Julia step worker (see run_jl_step()).

# Resolve a Julia version (e.g. "1.11") to a juliaup install's bin directory. juliaup keeps versions under <depot>/juliaup/julia-<version>+<build>/bin, where <depot> is $JULIA_DEPOT_PATH or ~/.julia. Returns the highest match.
.tp_juliaup_home <- function(version) {
  depot <- Sys.getenv("JULIA_DEPOT_PATH",
    unset = file.path(.tp_user_home(), ".julia"))
  # JULIA_DEPOT_PATH may be a list; take the first entry.
  depot <- strsplit(depot, .Platform$path.sep, fixed = TRUE)[[1]][1]
  root <- file.path(depot, "juliaup")
  hits <- Sys.glob(file.path(root, paste0("julia-", version, "*"), "bin"))
  if (length(hits) == 0L) {
    installed <- basename(dirname(Sys.glob(file.path(root, "julia-*", "bin"))))
    stop("No juliaup Julia matching version '", version, "' under ", root,
      if (length(installed)) paste0(". Installed: ", paste0(installed)) else "",
      ". Install it with `juliaup add ", version, "`, or set `julia_home` explicitly.",
      call. = FALSE)
  }
  # Pick the highest matching version numerically (lexicographic sort would rank e.g. julia-1.9 above julia-1.12). Dir names look like "julia-1.12.6+0.x64.w64.mingw32"; extract the x.y.z part for ordering.
  vers <- sub("^julia-([0-9]+(\\.[0-9]+)*).*$", "\\1", basename(dirname(hits)))
  hits[[order(numeric_version(vers), decreasing = TRUE)[[1]]]]
}

# Bind Julia making the caller's environment selection win over an ambient JULIA_PROJECT. This is the JuliaCall analogue of .tp_bind() for reticulate: Julia reads the JULIA_PROJECT environment variable *at startup* to choose the initially-active project environment, so an ambient one (e.g. set by an RStudio project config, a shell, or inherited by a crew worker) would silently override the environment the caller asked for: both an explicit `julia_project` (before we get to Pkg.activate it) and, more importantly, the *global* environment the caller requests by giving no `julia_project` at all. We clear it for the duration of the bind (it must be gone before julia_setup() starts Julia) so the caller's selection, or the default global environment, wins; then we restore it. JULIA_HOME is deliberately NOT cleared: it is a supported way to point at the default Julia (see zzz.R and the julia_home docs), and for an explicit julia_version/julia_home we pass JULIA_HOME to julia_setup() as an argument, which already takes precedence over the env var.
.tp_bind_julia <- function(bind_fn) {
  old <- Sys.getenv("JULIA_PROJECT", unset = NA_character_)
  if (!is.na(old) && nzchar(old)) {
    Sys.unsetenv("JULIA_PROJECT")
    on.exit(Sys.setenv(JULIA_PROJECT = old), add = TRUE)
  }
  bind_fn()
  invisible(TRUE)
}

# julia_version  : e.g. "1.11"; resolved to a juliaup bin dir when `julia_home`
#                  is not given. Lets you pick among juliaup-managed versions.
# julia_home     : directory containing the julia executable. Defaults to
#                  getOption("tarpolyglot.julia_home") (settable per-project or
#                  via the JULIA_HOME env var; see zzz.R). When NULL (and no
#                  julia_version), JuliaCall's own discovery is used (Julia on PATH).
# julia_project  : path to a Julia project environment (folder with
#                  Project.toml / Manifest.toml) to Pkg.activate(). When NULL,
#                  Julia's default global environment (@v#.#) is used (an ambient
#                  JULIA_PROJECT is cleared first; see .tp_bind_julia).
# julia_packages : character vector of packages to `using` before the script.
.tp_resolve_julia <- function(julia_version = NULL,
                              julia_home = getOption("tarpolyglot.julia_home"),
                              julia_project = NULL,
                              julia_packages = NULL) {
  if ((is.null(julia_home) || !nzchar(julia_home)) && !is.null(julia_version)) {
    julia_home <- .tp_juliaup_home(julia_version)
  }
  .tp_bind_julia(function() {
    setup_args <- list(installJulia = FALSE, verbose = FALSE)
    if (!is.null(julia_home) && nzchar(julia_home)) {
      setup_args$JULIA_HOME <- julia_home
    }
    do.call(JuliaCall::julia_setup, setup_args)

    if (!is.null(julia_project) && nzchar(julia_project)) {
      JuliaCall::julia_command(
        sprintf('import Pkg; Pkg.activate(raw"%s")', julia_project)
      )
    }
    if (!is.null(julia_packages)) {
      for (pkg in julia_packages) {
        JuliaCall::julia_command(sprintf("using %s", pkg))
      }
    }
  })
  invisible(TRUE)
}
