.onLoad <- function(libname, pkgname) {
  # Seed tarpolyglot.julia_home from the JULIA_HOME env var if set, so users can point JuliaCall at a specific Julia without editing package code. Leaving it NULL falls back to JuliaCall's own discovery (works once Julia is on PATH).
  op <- options()
  defaults <- list(
    tarpolyglot.julia_home = {
      jh <- Sys.getenv("JULIA_HOME", unset = "")
      if (nzchar(jh)) jh else NULL
    }
  )
  toset <- !(names(defaults) %in% names(op))
  if (any(toset)) options(defaults[toset])
  invisible()
}
