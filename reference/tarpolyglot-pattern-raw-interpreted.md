# Branching pattern for the interpreted-language `_raw` constructors

Branching pattern for the interpreted-language `_raw` constructors

## Arguments

- pattern:

  Optional targets dynamic-branching pattern as a language object (e.g.
  `quote(map(x))`), forwarded to
  [`targets::tar_target_raw()`](https://docs.ropensci.org/targets/reference/tar_target.html).
  The
  [`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md)
  family is also accepted and behaves identically to the plain `targets`
  patterns here (they only differ on the Rust constructor).
