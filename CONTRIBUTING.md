# Contributing

Development is a community effort, and we welcome participation.

## Code of Conduct

Please note that this package is released with a [Contributor Code of
Conduct](https://pierre9344.github.io/tarpolyglot/CODE_OF_CONDUCT.md).

## Issues

<https://github.com/Pierre9344/tarpolyglot/issues> is the place for all
of it: general questions, requests for help, bug reports, maintenance
tasks and feature requests. This repository has no Discussions section,
so please use issues throughout. There are templates for [bug
reports](https://pierre9344.github.io/tarpolyglot/ISSUE_TEMPLATE/bug_report.md)
and [feature
requests](https://pierre9344.github.io/tarpolyglot/ISSUE_TEMPLATE/feature_request.md).

A bug report is much easier to act on when it includes the output of
[`tarpolyglot::toolchain_check()`](https://pierre9344.github.io/tarpolyglot/reference/toolchain_check.md),
which reports what the package can actually find for each language,
along with [`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html),
the constructor involved, and a minimal `_targets.R` that reproduces the
problem. Please also say whether the failure happens while the target is
being constructed or while the pipeline runs, and whether dynamic
branching or a `crew` worker is involved, since those are the two
settings where polyglot steps behave differently.

## Development

External code contributions are extremely helpful in the right
circumstances. Here are the recommended steps.

1.  Prior to contribution, please propose your idea in an issue so you
    and the maintainer can define the intent and scope of your work.
2.  [Fork the
    repository](https://help.github.com/articles/fork-a-repo/).
3.  Follow the [GitHub
    flow](https://guides.github.com/introduction/flow/index.html) to
    create a new branch, add commits, and open a pull request.
4.  Discuss your code with the maintainer in the pull request thread.
5.  If everything looks good, the maintainer will merge your code into
    the project.

Please also follow these additional guidelines.

- Respect the architecture and reasoning of the package. The vignettes
  (`get_started`, `python`, `julia`, `rust`, `cpp`, `scripts`) are the
  design documents; read the one for the language you are touching. A
  change to the pre/post-script contract usually touches both a
  constructor in `R/tar-target-*.R` and its worker in `R/run-step*.R`,
  so keep the two in step.
- If possible, keep contributions small enough to easily review
  manually. It is okay to split up your work into multiple pull
  requests.
- Format your code according to the [tidyverse style
  guide](https://style.tidyverse.org/). Internal functions are prefixed
  `.tp_` and stay unexported.
- Regenerate the documentation with `devtools::document()`. `man/` and
  `NAMESPACE` are generated, so never edit them by hand. Shared argument
  documentation lives in `R/shared-params.R` and is pulled in with
  `@inheritParams tarpolyglot-shared-params`, and `README.md` is knitted
  from `README.Rmd` with `devtools::build_readme()`. A newly exported
  function also needs an entry in `_pkgdown.yml`.
- For new features or functionality, add tests in `tests/testthat/`.
  Offline tests that construct a target and inspect the result run by
  default. Tests that start an interpreter or invoke a compiler must be
  gated behind the `TARPOLYGLOT_INTEGRATION` environment variable,
  following the pattern in the existing `test-integration-*.R` files, so
  that the default test run and `R CMD check` stay fast and offline. Run
  the gated tests with
  `Sys.setenv(TARPOLYGLOT_INTEGRATION = "true"); devtools::test()`.
- Each language toolchain is optional and is only needed by its own
  constructor, so guard a gated test on the toolchain as well as on the
  variable, using `skip_if_not_installed()` and an availability check.
  Someone who has Python but not Julia should still get a clean run. Use
  [`withr::local_tempfile()`](https://withr.r-lib.org/reference/with_tempfile.html)
  and
  [`withr::local_tempdir()`](https://withr.r-lib.org/reference/with_tempfile.html)
  for the scripts and libraries these tests create.
- Check code coverage with `covr::package_coverage()`. Automated tests
  should cover all the new or changed functionality in your pull
  request.
- Run overall package checks with `devtools::check()`.
- Describe your contribution in the project’s
  [`NEWS.md`](https://pierre9344.github.io/tarpolyglot/NEWS.md) file. Be
  sure to mention relevant GitHub issue numbers and your GitHub name as
  done in existing news entries.
- If you feel your contribution is substantial enough for official
  author or contributor status, please add yourself to the `Authors@R`
  field of the
  [`DESCRIPTION`](https://pierre9344.github.io/tarpolyglot/DESCRIPTION)
  file.
- In the pull request, say which platform you tested on and which
  toolchains you had available. “Offline tests only, no Julia locally”
  is genuinely useful information for a reviewer.

## Continuous integration

Pull requests run `R CMD check` and coverage, plus a separate
integration workflow that installs real Python, Julia and Rust
toolchains and sets `TARPOLYGLOT_INTEGRATION=true`, so the gated tests
execute there even if you could not run them on your own machine.

If you change `.github/workflows/tarpolyglot-integration.yaml`, please
read the comments in it first and preserve them. They record why
JuliaCall is pinned to a patched upstream revision on Ubuntu, why Rust
needs the GNU target added on Windows while the host toolchain stays
MSVC, and why the job installs tarpolyglot itself rather than only its
dependencies.
