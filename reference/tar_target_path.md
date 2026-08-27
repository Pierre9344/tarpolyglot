# Track a script argument as a `targets` dependency

Use as the `script`, `pre_script`, or `post_script` argument of
[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md)/[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md)/[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)
(and their `_raw` forms) instead of a literal path string, to make that
step re-run whenever the script file changes. `name` is the name of an
upstream `targets` target (typically one created with `format = "file"`
tracking the script file), and its *value* (the file path) is
substituted in when the pipeline runs.

## Usage

``` r
tar_target_path(name)
```

## Arguments

- name:

  Character string, the name of an upstream target whose value is the
  script's file path (e.g. a `tar_target(..., format = "file")`).

## Value

An object marking `name` for dependency-wiring by the `tar_target_*`
constructors.

## Details

This mirrors how `inputs = c(x = "some_target")` already wires an
upstream target in by name: the target's name is given as a string, and
the constructor turns it into a real dependency. A plain string passed
directly as `script`/`pre_script`/`post_script` keeps meaning what it
always has (an untracked literal path), so existing pipelines are
unaffected.

## See also

[`tar_target_py()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_py.md),
[`tar_target_jl()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_jl.md),
[`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md)

## Examples

``` r
# Building a target does not run it, so this example needs no Python.
# python/fit_step.py:
#   result = sum(x)
# scripts/pre.R:
#   to_py <- list(x = x)
list(
  targets::tar_target(fit_pyscript, "python/fit_step.py", format = "file"),
  tar_target_py(
    name = fit,
    script = tar_target_path("fit_pyscript"),  # re-runs when the file changes
    pre_script = "scripts/pre.R",              # untracked literal path
    inputs = c(x = "prepared_x"),
    retrieve = "result"
  )
)
#> [[1]]
#> <tar_stem> 
#>   name: fit_pyscript 
#>   description:  
#>   command:
#>     "python/fit_step.py" 
#>   format: file 
#>   repository: local 
#>   iteration method: vector 
#>   error mode: stop 
#>   memory mode: auto 
#>   storage mode: worker 
#>   retrieval mode: auto 
#>   deployment mode: worker 
#>   priority: 0 
#>   resources:
#>     list() 
#>   cue:
#>     seed: TRUE
#>     file: TRUE
#>     iteration: TRUE
#>     repository: TRUE
#>     format: TRUE
#>     depend: TRUE
#>     command: TRUE
#>     mode: thorough 
#>   packages:
#>     tarpolyglot
#>     stats
#>     graphics
#>     grDevices
#>     utils
#>     datasets
#>     methods
#>     base 
#>   library:
#>     NULL
#> [[2]]
#> <tar_stem> 
#>   name: fit 
#>   description:  
#>   command:
#>     tarpolyglot::run_py_step(script = fit_pyscript, pre_script = "scripts/pre.R", 
#>         post_script = NULL, inputs = list(x = prepared_x), output = "object", 
#>         retrieve = "result", files = NULL, python_version = NULL, 
#>         env = NULL, env_manager = "system", python = NULL, name = "fit") 
#>   format: rds 
#>   repository: local 
#>   iteration method: vector 
#>   error mode: stop 
#>   memory mode: auto 
#>   storage mode: worker 
#>   retrieval mode: auto 
#>   deployment mode: worker 
#>   priority: 0 
#>   resources:
#>     list() 
#>   cue:
#>     seed: TRUE
#>     file: TRUE
#>     iteration: TRUE
#>     repository: TRUE
#>     format: TRUE
#>     depend: TRUE
#>     command: TRUE
#>     mode: thorough 
#>   packages:
#>     tarpolyglot
#>     stats
#>     graphics
#>     grDevices
#>     utils
#>     datasets
#>     methods
#>     base 
#>   library:
#>     NULL
```
