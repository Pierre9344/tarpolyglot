# Post-script argument for the compiled-language constructors

Rust and C++ share the same post-script contract: there is no pre-script
and no live interpreter, so the compiled functions are called from an R
script run after the build. Python and Julia differ (they have a
pre-script and an interpreter hand-off), so they keep their own wording.

## Arguments

- post_script:

  Path to an R script run after compilation, where the compiled
  functions and `inputs` are in scope. Its last expression is the value
  (object mode); it returns file paths (file mode). Required for object
  mode. Accepts a literal path, a
  [`tar_target_path()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_path.md)
  reference, or inline code from
  [`tar_code()`](https://pierre9344.github.io/tarpolyglot/reference/tar_code.md);
  see the "Script options" section below.
