# Dynamic-branching pattern helpers for tarpolyglot constructors, plus the
# internal normalizer that turns them into plain `targets` patterns.
#
# A tarpolyglot pattern helper (currently `tarpolyglot_map()`) is used exactly
# like the `targets` helper it mirrors: unquoted in the `pattern` argument of a
# tarpolyglot constructor. On the Python/Julia constructors it is identical to
# the plain `targets` pattern. On the Rust and C++ constructors it
# additionally asks the crate/library to be compiled once and reused across
# every branch (see `tar_target_rs()` / `tar_target_cpp()`), instead of
# recompiling in each branch. This file (the marker functions and the
# `.tp_pattern()` normalizer below) is itself toolchain-agnostic: it only
# flags "a compile-once helper was used" and rewrites to the plain `targets`
# pattern. Each constructor decides what "compile once" means for its own
# language (`.tp_rs_compile_once()` in tar-target-rs.R, `.tp_cpp_compile_once()`
# in tar-target-cpp.R) -- nothing here needs to change to add a language.

# Map each tarpolyglot helper name to the plain `targets` pattern it becomes.
.tp_pattern_helpers <- c(
  tarpolyglot_map = "map",
  tarpolyglot_cross = "cross",
  tarpolyglot_slice = "slice",
  tarpolyglot_head = "head",
  tarpolyglot_tail = "tail",
  tarpolyglot_sample = "sample"
)

# Inspect and normalize a dynamic-branching pattern captured as a language
# object. Returns a list with:
#   * compile_once: TRUE if the pattern uses a tarpolyglot_*() helper (the Rust
#     constructor then builds the crate once and reuses it across branches; the
#     Python/Julia constructors ignore the flag).
#   * pattern: the equivalent plain-`targets` pattern (tarpolyglot_map -> map,
#     ...), which is what we hand to targets::tar_target_raw() for every
#     constructor. A plain `map(...)` pattern (or NULL) passes through unchanged.
# The rewrite recurses so a helper nested inside a composite pattern is handled
# too, and it accepts both the bare `tarpolyglot_map` and the namespaced
# `tarpolyglot::tarpolyglot_map` forms.
.tp_pattern <- function(pattern) {
  state <- new.env(parent = emptyenv())
  state$hit <- FALSE

  rewrite <- function(x) {
    if (!is.call(x)) {
      return(x)
    }
    head <- x[[1L]]
    # Unwrap `tarpolyglot::tarpolyglot_map` to the bare helper name.
    bare <- head
    if (is.call(head) && identical(head[[1L]], as.name("::")) &&
        identical(head[[2L]], as.name("tarpolyglot"))) {
      bare <- head[[3L]]
    }
    if (is.name(bare)) {
      nm <- as.character(bare)
      if (nm %in% names(.tp_pattern_helpers)) {
        state$hit <- TRUE
        x[[1L]] <- as.name(.tp_pattern_helpers[[nm]])
      }
    }
    # Recurse into the arguments (patterns can nest, e.g. cross(map(a), b)).
    for (i in seq_along(x)[-1L]) {
      x[[i]] <- rewrite(x[[i]])
    }
    x
  }

  pattern <- rewrite(pattern)
  list(compile_once = state$hit, pattern = pattern)
}

#' Dynamic-branching map that compiles Rust/C++ once
#'
#' A drop-in replacement for the \pkg{targets} [targets::tar_target()] pattern helper `map()`, for use unquoted in the `pattern` argument of a tarpolyglot constructor ([tar_target_rs()], [tar_target_cpp()], [tar_target_py()], [tar_target_jl()], and their `_raw` forms).
#'
#' On [tar_target_rs()] and [tar_target_cpp()] it changes how the branches are built: the crate/library is compiled **once** in a companion target named `<name>_rust_lib` / `<name>_cpp_lib`, and every branch reuses that compiled library instead of recompiling. Recompiling per branch is otherwise the default, because Rust and C++ have no live interpreter (contrast Python/Julia, whose interpreter is simply reused). With three branches this turns roughly `3 x compile` into `1 x compile + 3 x (near-instant reload)`.
#'
#' On [tar_target_py()] and [tar_target_jl()] there is nothing to compile, so `tarpolyglot_map()` is exactly `map()`: it is provided so the same pipeline code can branch every language uniformly.
#'
#' Use it wherever you would write `map()`: `pattern = tarpolyglot_map(x)`. The arguments are upstream target names to iterate over in parallel, with the same meaning as [targets::tar_target()]'s `map()`.
#'
#' @section Only recognised by tarpolyglot constructors:
#' The `tarpolyglot_*()` pattern helpers work only inside the `pattern` argument of the tarpolyglot constructors ([tar_target_rs()], [tar_target_cpp()], [tar_target_py()], [tar_target_jl()], and their `_raw()` forms), which rewrite them to the plain \pkg{targets} pattern before building the target. Used directly in a plain [targets::tar_target()] or [targets::tar_target_raw()] they raise an error such as `invalid dynamic branching pattern ... Illegal symbols found: tarpolyglot_map`, because \pkg{targets} validates a pattern against its own fixed set of pattern functions and does not know these helpers. This cannot be fixed from tarpolyglot: \pkg{targets} looks its pattern functions up in a locked internal environment, so teaching it a new one would require modifying the \pkg{targets} package itself. In a plain \pkg{targets} target (which has no foreign code to compile, so nothing to gain) use the native `map()` / `cross()` / `slice()` / `head()` / `tail()` / `sample()` instead.
#'
#' @param ... Upstream targets to map over in parallel, exactly as in the \pkg{targets} `map()` pattern (e.g. `tarpolyglot_map(x)` or `tarpolyglot_map(x, y)`).
#'
#' @return This function is a marker consumed by the tarpolyglot constructors and is not meant to be evaluated on its own; calling it directly raises an error.
#' @seealso The other pattern helpers: [tarpolyglot_cross()], [tarpolyglot_slice()], [tarpolyglot_head()], [tarpolyglot_tail()], [tarpolyglot_sample()]. The constructors that accept them: [tar_target_rs()], [tar_target_cpp()], [tar_target_py()], [tar_target_jl()]
#' @examples
#' # rs/square.rs:
#' #   #[extendr]
#' #   fn square(x: f64) -> f64 { x * x }
#' # R/post_square.R:
#' #   square(x)
#' list(
#'   targets::tar_target(vals, c(10, 20, 30)),
#'   # Rust: compiles rs/square.rs once in `rs_branch_rust_lib`, then squares
#'   # each branch value reusing that compiled library.
#'   tarpolyglot::tar_target_rs(
#'     name = rs_branch,
#'     script = "rs/square.rs",
#'     inputs = c(x = "vals"),
#'     post_script = "R/post_square.R",
#'     pattern = tarpolyglot_map(vals)
#'   )
#' )
#' @export
tarpolyglot_map <- function(...) {
  .tp_pattern_marker("tarpolyglot_map")
}

# Shared error for the pattern-helper markers: they only mean something unquoted
# in the `pattern` argument, where the constructors read them symbolically.
.tp_pattern_marker <- function(fn) {
  stop(
    "`", fn, "()` is only meant to be used unquoted in the `pattern` argument ",
    "of a tarpolyglot constructor (tar_target_rs() / tar_target_cpp() / ",
    "tar_target_py() / tar_target_jl()); it is not a function to call directly.",
    call. = FALSE
  )
}

#' Dynamic-branching cross that compiles Rust once
#'
#' A drop-in replacement for the \pkg{targets} [targets::tar_target()] pattern helper `cross()`, for use unquoted in the `pattern` argument of a tarpolyglot constructor. Like [tarpolyglot_map()], on [tar_target_rs()] it compiles the extendr crate **once** in a companion `<name>_rust_lib` target and reuses it across every branch (instead of recompiling per branch); on [tar_target_py()] / [tar_target_jl()] it is exactly `cross()`. See [tarpolyglot_map()] for the full explanation and the compile-once mechanics.
#'
#' @param ... Upstream targets to cross (all combinations), with the same meaning as in the \pkg{targets} `cross()` pattern.
#'
#' @inherit tarpolyglot_map return
#' @inheritSection tarpolyglot_map Only recognised by tarpolyglot constructors
#' @seealso The other pattern helpers: [tarpolyglot_map()], [tarpolyglot_slice()], [tarpolyglot_head()], [tarpolyglot_tail()], [tarpolyglot_sample()]. The constructors that accept them: [tar_target_rs()], [tar_target_cpp()], [tar_target_py()], [tar_target_jl()]
#' @examples
#' # square.rs:
#' #   #[extendr]
#' #   fn square(x: f64) -> f64 { x * x }
#' # post.R:
#' #   square(x)
#' tarpolyglot::tar_target_rs(
#'   name = rs_grid, script = "square.rs", inputs = c(x = "a", y = "b"),
#'   post_script = "post.R", pattern = tarpolyglot_cross(a, b)
#' )
#' @export
tarpolyglot_cross <- function(...) {
  .tp_pattern_marker("tarpolyglot_cross")
}

#' Dynamic-branching slice that compiles Rust once
#'
#' A drop-in replacement for the \pkg{targets} [targets::tar_target()] pattern helper `slice()`, for use unquoted in the `pattern` argument of a tarpolyglot constructor. Like [tarpolyglot_map()], on [tar_target_rs()] it compiles the extendr crate **once** in a companion `<name>_rust_lib` target and reuses it across the selected branches; on [tar_target_py()] / [tar_target_jl()] it is exactly `slice()`. See [tarpolyglot_map()] for the full explanation and the compile-once mechanics.
#'
#' @param ... Upstream target(s) to branch over, with the same meaning as in the \pkg{targets} `slice()` pattern.
#' @param index Integer vector of branch indices to keep, as in the \pkg{targets} `slice()` pattern.
#'
#' @inherit tarpolyglot_map return
#' @inheritSection tarpolyglot_map Only recognised by tarpolyglot constructors
#' @seealso The other pattern helpers: [tarpolyglot_map()], [tarpolyglot_cross()], [tarpolyglot_head()], [tarpolyglot_tail()], [tarpolyglot_sample()]. The constructors that accept them: [tar_target_rs()], [tar_target_cpp()], [tar_target_py()], [tar_target_jl()]
#' @examples
#' # square.rs:
#' #   #[extendr]
#' #   fn square(x: f64) -> f64 { x * x }
#' # post.R:
#' #   square(x)
#' tarpolyglot::tar_target_rs(
#'   name = rs_some, script = "square.rs", inputs = c(x = "vals"),
#'   post_script = "post.R", pattern = tarpolyglot_slice(vals, index = c(1, 3))
#' )
#' @export
tarpolyglot_slice <- function(..., index) {
  .tp_pattern_marker("tarpolyglot_slice")
}

#' Dynamic-branching head that compiles Rust once
#'
#' A drop-in replacement for the \pkg{targets} [targets::tar_target()] pattern helper `head()`, for use unquoted in the `pattern` argument of a tarpolyglot constructor. Like [tarpolyglot_map()], on [tar_target_rs()] it compiles the extendr crate **once** in a companion `<name>_rust_lib` target and reuses it across the kept branches; on [tar_target_py()] / [tar_target_jl()] it is exactly `head()`. See [tarpolyglot_map()] for the full explanation and the compile-once mechanics.
#'
#' @param ... Upstream target(s) to branch over, with the same meaning as in the \pkg{targets} `head()` pattern.
#' @param n Number of branches to keep from the start, as in the \pkg{targets} `head()` pattern.
#'
#' @inherit tarpolyglot_map return
#' @inheritSection tarpolyglot_map Only recognised by tarpolyglot constructors
#' @seealso The other pattern helpers: [tarpolyglot_map()], [tarpolyglot_cross()], [tarpolyglot_slice()], [tarpolyglot_tail()], [tarpolyglot_sample()]. The constructors that accept them: [tar_target_rs()], [tar_target_cpp()], [tar_target_py()], [tar_target_jl()]
#' @examples
#' # square.rs:
#' #   #[extendr]
#' #   fn square(x: f64) -> f64 { x * x }
#' # post.R:
#' #   square(x)
#' tarpolyglot::tar_target_rs(
#'   name = rs_first, script = "square.rs", inputs = c(x = "vals"),
#'   post_script = "post.R", pattern = tarpolyglot_head(vals, n = 2)
#' )
#' @export
tarpolyglot_head <- function(..., n) {
  .tp_pattern_marker("tarpolyglot_head")
}

#' Dynamic-branching tail that compiles Rust once
#'
#' A drop-in replacement for the \pkg{targets} [targets::tar_target()] pattern helper `tail()`, for use unquoted in the `pattern` argument of a tarpolyglot constructor. Like [tarpolyglot_map()], on [tar_target_rs()] it compiles the extendr crate **once** in a companion `<name>_rust_lib` target and reuses it across the kept branches; on [tar_target_py()] / [tar_target_jl()] it is exactly `tail()`. See [tarpolyglot_map()] for the full explanation and the compile-once mechanics.
#'
#' @param ... Upstream target(s) to branch over, with the same meaning as in the \pkg{targets} `tail()` pattern.
#' @param n Number of branches to keep from the end, as in the \pkg{targets} `tail()` pattern.
#'
#' @inherit tarpolyglot_map return
#' @inheritSection tarpolyglot_map Only recognised by tarpolyglot constructors
#' @seealso The other pattern helpers: [tarpolyglot_map()], [tarpolyglot_cross()], [tarpolyglot_slice()], [tarpolyglot_head()], [tarpolyglot_sample()]. The constructors that accept them: [tar_target_rs()], [tar_target_cpp()], [tar_target_py()], [tar_target_jl()]
#' @examples
#' # square.rs:
#' #   #[extendr]
#' #   fn square(x: f64) -> f64 { x * x }
#' # post.R:
#' #   square(x)
#' tarpolyglot::tar_target_rs(
#'   name = rs_last, script = "square.rs", inputs = c(x = "vals"),
#'   post_script = "post.R", pattern = tarpolyglot_tail(vals, n = 2)
#' )
#' @export
tarpolyglot_tail <- function(..., n) {
  .tp_pattern_marker("tarpolyglot_tail")
}

#' Dynamic-branching sample that compiles Rust once
#'
#' A drop-in replacement for the \pkg{targets} [targets::tar_target()] pattern helper `sample()`, for use unquoted in the `pattern` argument of a tarpolyglot constructor. Like [tarpolyglot_map()], on [tar_target_rs()] it compiles the extendr crate **once** in a companion `<name>_rust_lib` target and reuses it across the sampled branches; on [tar_target_py()] / [tar_target_jl()] it is exactly `sample()`. See [tarpolyglot_map()] for the full explanation and the compile-once mechanics.
#'
#' @param ... Upstream target(s) to branch over, with the same meaning as in the \pkg{targets} `sample()` pattern.
#' @param n Number of branches to sample at random, as in the \pkg{targets} `sample()` pattern.
#'
#' @inherit tarpolyglot_map return
#' @inheritSection tarpolyglot_map Only recognised by tarpolyglot constructors
#' @seealso The other pattern helpers: [tarpolyglot_map()], [tarpolyglot_cross()], [tarpolyglot_slice()], [tarpolyglot_head()], [tarpolyglot_tail()]. The constructors that accept them: [tar_target_rs()], [tar_target_cpp()], [tar_target_py()], [tar_target_jl()]
#' @examples
#' # square.rs:
#' #   #[extendr]
#' #   fn square(x: f64) -> f64 { x * x }
#' # post.R:
#' #   square(x)
#' tarpolyglot::tar_target_rs(
#'   name = rs_rand, script = "square.rs", inputs = c(x = "vals"),
#'   post_script = "post.R", pattern = tarpolyglot_sample(vals, n = 2)
#' )
#' @export
tarpolyglot_sample <- function(..., n) {
  .tp_pattern_marker("tarpolyglot_sample")
}
