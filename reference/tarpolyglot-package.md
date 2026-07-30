# tarpolyglot: run Python, Julia, and Rust as targets pipeline steps

## Details

tarpolyglot provides target constructors that execute Python, Julia, and
Rust code inside a [targets](https://docs.ropensci.org/targets/)
pipeline, using reticulate (Python), JuliaCall (Julia), and rextendr
(Rust).

The user-facing constructors mirror the targets pair:

- [`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md)
  /
  [`tar_target_py_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py_raw.md)
  for Python,

- [`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md)
  /
  [`tar_target_jl_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl_raw.md)
  for Julia,

- [`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)
  /
  [`tar_target_rs_raw()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs_raw.md)
  for Rust (compiled via rextendr/extendr; see
  [`vignette("rust")`](https://pierre9344.github.io/tarpolyglot/articles/rust.md)).

The non-`_raw` forms use non-standard evaluation on `name`/`pattern` and
are meant for direct use in `_targets.R`; the `_raw` forms take a string
`name` and are meant for use inside targets factories. Each constructor
returns a single `targets` target object.

A Python/Julia step may combine up to three scripts: an optional R
**pre-script** (prepare inputs), the required **foreign script**, and an
optional R **post-script** (retrieve results). A Rust step has no
pre-script: its `#[extendr]` functions are compiled and then called from
the R post-script. Output is returned either as a converted R object or
as a character vector of files on disk (`output = "file"`).

Start with
[`vignette("get_started")`](https://pierre9344.github.io/tarpolyglot/articles/get_started.md)
(motivation, limitations, a worked pipeline, and `crew`-based
parallelism/isolation), then the per-language vignettes
[`vignette("python")`](https://pierre9344.github.io/tarpolyglot/articles/python.md),
[`vignette("julia")`](https://pierre9344.github.io/tarpolyglot/articles/julia.md),
and
[`vignette("rust")`](https://pierre9344.github.io/tarpolyglot/articles/rust.md).

## See also

Useful links:

- <https://github.com/Pierre9344/tarpolyglot>

- <https://pierre9344.github.io/tarpolyglot/>

- Report bugs at <https://github.com/Pierre9344/tarpolyglot/issues>

## Author

**Maintainer**: Pierre Solomon <pierre.solomon@laposte.net>
([ORCID](https://orcid.org/0000-0001-7187-2664))

Authors:

- Pierre Solomon <pierre.solomon@laposte.net>
  ([ORCID](https://orcid.org/0000-0001-7187-2664))
