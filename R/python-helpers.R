# Configure the reticulate Python binding for the current R session. reticulate can bind only one interpreter per session, so this is called once at the start of each Python step worker (see run_py_step()).

# Resolve `env` to an absolute path when it refers to an already-existing directory (a relative or absolute path to a venv/project already on disk), leaving it unchanged otherwise. This lets `env` be given as a path relative to the pipeline's working directory (e.g. ".venv-mofaflex", "envs/uv-venv") without reticulate::use_virtualenv() misreading a separator-less relative path as the NAME of an environment to look up under its own virtualenv root (~/.virtualenvs/<name> and similar) instead of a path on disk. A bare name that does NOT correspond to an existing directory is passed through untouched, so genuine named-environment lookups (env_manager = "virtualenv"/"uv" with a name previously created under that root) keep working.
.tp_resolve_env_path <- function(env) {
  if (is.null(env) || !dir.exists(env)) {
    return(env)
  }
  normalizePath(env, winslash = "/", mustWork = TRUE)
}

# Resolve a poetry project directory to its virtualenv path. The poetry executable defaults to "poetry" on PATH but can be overridden with options(tarpolyglot.poetry = "<path to poetry>") for machines where the PATH poetry is missing/broken.
.tp_poetry_venv <- function(project = ".") {
  poetry <- getOption("tarpolyglot.poetry", "poetry")
  path <- tryCatch(
    system2(poetry, c("-C", project, "env", "info", "-p"),
      stdout = TRUE, stderr = TRUE),
    error = function(e) character(0)
  )
  path <- path[nzchar(path)]
  if (length(path) == 0L || !dir.exists(path[[length(path)]])) {
    stop("Could not resolve a poetry virtualenv for project '", project,
      "'. Is poetry installed and the project initialised?", call. = FALSE)
  }
  path[[length(path)]]
}

# Bind the interpreter selected by an *explicit* request (an interpreter path or a concrete environment), making that selection win over an ambient RETICULATE_PYTHON. RStudio exports RETICULATE_PYTHON from a project's Python config, and crew workers inherit it; reticulate otherwise lets it override use_python()/use_virtualenv() (silently ignoring the request; see reticulate's "Order of Discovery"). We temporarily clear it while binding, so the caller's `python`/`env`/`env_manager` is honoured, then restore it. Deliberately NOT applied to the system/python_version/default cases, which are meant to respect the ambient RETICULATE_PYTHON.
.tp_bind <- function(bind_fn) {
  old <- Sys.getenv("RETICULATE_PYTHON", unset = NA_character_)
  if (!is.na(old) && nzchar(old)) {
    Sys.unsetenv("RETICULATE_PYTHON")
    on.exit(Sys.setenv(RETICULATE_PYTHON = old), add = TRUE)
  }
  bind_fn()
  invisible(reticulate::py_config())
}

# Resolve the reticulate Python binding. Precedence (first match wins):
#   1. `python`         explicit interpreter path                -> use_python()
#   2. an environment   env_manager != "system" (or `env` given) -> use_virtualenv/use_condaenv()
#   3. `python_version` a version like "3.12"                    -> py_require()
#   4. nothing set      -> reticulate's default (computer/global Python)
#
# Cases 1 and 2 clear an ambient RETICULATE_PYTHON for the duration of the bind (see .tp_bind) so the explicit selection is not overridden; cases 3 and 4 leave it in place.
#
# python_version : e.g. "3.12" or ">=3.11"; only used in case 3 (system, no env,
#                  no explicit path). reticulate fetches/selects it via uv.
# env            : venv/virtualenv name/path, conda env name, or poetry project dir.
# env_manager    : how to interpret `env`.
# python         : explicit interpreter path.
.tp_resolve_python <- function(python_version = NULL,
                               env = NULL,
                               env_manager = "system",
                               python = NULL) {
  env_manager <- match.arg(
    env_manager,
    c("system", "virtualenv", "venv", "conda", "uv", "poetry")
  )

  # 1. Explicit interpreter path wins.
  if (!is.null(python)) {
    if (!is.null(python_version)) {
      warning("`python_version` is ignored when an explicit `python` path is set.",
        call. = FALSE)
    }
    return(.tp_bind(function() reticulate::use_python(python, required = TRUE)))
  }

  # 2. A concrete environment (any non-system manager, or an `env` value).
  if (!identical(env_manager, "system") || !is.null(env)) {
    if (identical(env_manager, "system")) {
      stop("`env` was supplied but `env_manager` is 'system'. Set `env_manager` ",
        "to one of 'virtualenv', 'venv', 'conda', 'uv', 'poetry'.", call. = FALSE)
    }
    if (!is.null(python_version)) {
      warning("`python_version` is ignored when an environment is selected; the ",
        "environment determines the Python version.", call. = FALSE)
    }
    return(.tp_bind(function() {
      switch(env_manager,
        # virtualenv, venv and uv all produce standard virtualenvs (whether made by `python -m venv`, the virtualenv tool, uv, or renv::use_python()), so they resolve the same way.
        virtualenv = ,
        venv = ,
        uv = {
          if (is.null(env)) {
            stop("`env` (virtualenv name or path) is required for ",
              "env_manager = '", env_manager, "'.", call. = FALSE)
          }
          reticulate::use_virtualenv(.tp_resolve_env_path(env), required = TRUE)
        },
        conda = {
          if (is.null(env)) {
            stop("`env` (conda environment name) is required for ",
              "env_manager = 'conda'.", call. = FALSE)
          }
          reticulate::use_condaenv(env, required = TRUE)
        },
        poetry = {
          reticulate::use_virtualenv(.tp_poetry_venv(.tp_resolve_env_path(if (is.null(env)) "." else env)), required = TRUE)
        }
      )
    }))
  }

  # 3. A requested Python version (system default, but pin the version). Use reticulate's uv-backed ephemeral environment via py_require(); this avoids use_python_version()'s pyenv path, which is unreliable on Windows.
  if (!is.null(python_version)) {
    reticulate::py_require(python_version = as.character(python_version))
  }
  # 4. Otherwise leave reticulate's default in place.
  invisible(reticulate::py_config())
}
