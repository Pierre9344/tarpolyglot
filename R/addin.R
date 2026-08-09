# RStudio addin bindings for toolchain_check() (see inst/rstudio/addins.dcf
# and https://rstudio.github.io/rstudio-extensions/rstudio_addins.html).
# Each is a thin, zero-argument wrapper invoked from the RStudio Addins menu.
# Not exported: RStudio resolves addin bindings from the package's namespace
# regardless of export status, the same pattern the `targets` package itself
# uses for its own rstudio_addin_*() functions (tar_visnetwork, tar_load, ...).

rstudio_addin_toolchain_check_all <- function() {
  toolchain_check()
  invisible(NULL)
}

rstudio_addin_toolchain_check_py <- function() {
  toolchain_check("py")
  invisible(NULL)
}

rstudio_addin_toolchain_check_jl <- function() {
  toolchain_check("jl")
  invisible(NULL)
}

rstudio_addin_toolchain_check_rs <- function() {
  toolchain_check("rs")
  invisible(NULL)
}
