# Branching pattern for the compiled-language NSE constructors

Branching pattern for the compiled-language NSE constructors

## Arguments

- pattern:

  Optional branching pattern as described in the [targets package
  documentation](https://books.ropensci.org/targets/dynamic.html#patterns),
  unquoted (e.g. `map(x)`). The patterns included in the targets package
  (`map()`, [`head()`](https://rdrr.io/r/utils/head.html), ...) are
  accepted, but it is recommended to use the tarpolyglot pattern
  functions instead, as they compile the library once and reuse it
  across the branches (see
  [`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md),
  [`tarpolyglot_head()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_head.md),
  [`tarpolyglot_tail()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_tail.md),
  [`tarpolyglot_cross()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_cross.md),
  [`tarpolyglot_slice()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_slice.md),
  [`tarpolyglot_sample()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_sample.md)).
