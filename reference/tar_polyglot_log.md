# Configure per-step stdout/stderr logging

Passed to
[`polyglot_controller()`](https://pierre9344.github.io/tarpolyglot/reference/polyglot_controller.md)'s
`log` argument to write one log file per Python/Julia step: `<name>.out`
for stdout, `<name>.err` for stderr, named after the target. crew
launches worker processes before it knows which target they will run, so
this configuration cannot be applied at worker-launch time; instead
[`polyglot_controller()`](https://pierre9344.github.io/tarpolyglot/reference/polyglot_controller.md)
stashes it as environment variables (inherited by every worker process
it spawns, the same way any other environment variable is), and
[`run_py_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_py_step.md)
/
[`run_jl_step()`](https://pierre9344.github.io/tarpolyglot/reference/run_jl_step.md)
read them back and do the actual redirection once they know which step
is running and what interpreter it resolved.

## Usage

``` r
tar_polyglot_log(
  stdout = "./logs/out",
  stderr = "./logs/err",
  append = FALSE,
  header = TRUE
)
```

## Arguments

- stdout, stderr:

  Directory to write per-step log files into (created if missing), or
  `NULL` to disable that stream. Default `"./logs/out"` /
  `"./logs/err"`.

- append:

  If `FALSE` (default), a step's log file is truncated at the start of
  that step's run, so it only ever holds the latest run's output. If
  `TRUE`, new output is appended after two blank lines separating it
  from any prior content, so the file accumulates history across
  repeated runs.

- header:

  If `TRUE` (default), the stdout file gets a header written before the
  step's own output: the step name,
  [`date()`](https://rdrr.io/r/base/date.html), the resolved
  interpreter's version and path, and whether an explicit environment
  was used.

## Value

A list with class `tp_log`, for `polyglot_controller(log = ...)`.

## Details

Rust steps
([`tar_target_rs()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_rs.md))
are not covered: rextendr-compiled code writes straight to the OS file
descriptor, bypassing the redirection mechanism reticulate/JuliaCall
provide for their embedded interpreters. Use crew's own
`options_local(log_directory = ...)` (process-level logging; since
[`polyglot_controller()`](https://pierre9344.github.io/tarpolyglot/reference/polyglot_controller.md)
defaults to `tasks_max = 1`, each worker runs exactly one step, so that
already gives one log per step, Rust included) if you need Rust step
output.

C++ steps
([`tar_target_cpp()`](https://pierre9344.github.io/tarpolyglot/reference/tar_target_cpp.md))
**are** covered, with one caveat: `Rcpp::Rcout`/`Rcpp::Rcerr` (the
idiomatic Rcpp printing calls) route through R's own output-connection
system, so they are captured by an R-level
[`sink()`](https://rdrr.io/r/base/sink.html) redirect the same way
[`cat()`](https://rdrr.io/r/base/cat.html)/[`message()`](https://rdrr.io/r/base/message.html)
output is (confirmed empirically, including from a fresh crew worker
process). Raw `std::cout`/`std::cerr`/`printf()` writes bypass R's
connection system entirely and write straight to the OS file descriptor,
exactly like Rust's `println!()` – **not** captured here; use
`Rcpp::Rcout`/`Rcpp::Rcerr` in compiled code instead of raw C++ streams
if you want step output in these logs.

**Branches of one `pattern` share a single log file,
language-agnostically.** The log file name is fixed to the *target*'s
name at the moment its command is built, before branching happens – so
every branch of a
`map()`/[`tarpolyglot_map()`](https://pierre9344.github.io/tarpolyglot/reference/tarpolyglot_map.md)-driven
step (Python, Julia, or C++ alike) writes to the same
`<name>.out`/`<name>.err`, and since `append = FALSE` truncates at the
start of *each* branch's run, only the last branch to run leaves its
output in the file; earlier branches' output is overwritten, not
lost-and-gone from disk but never actually visible. Not specific to C++
– confirmed while investigating C++ logging, but the same
file-per-target-name design applies to every constructor. Use
`append = TRUE` to at least keep all branches' output (separated, in run
order) instead of losing all but the last, or `crew`'s own
`options_local(log_directory = ...)` for a genuinely
one-file-per-worker-process log.

## See also

[`polyglot_controller()`](https://pierre9344.github.io/tarpolyglot/reference/polyglot_controller.md)

## Examples

``` r
if (FALSE) { # \dontrun{
targets::tar_option_set(
  controller = tarpolyglot::polyglot_controller(
    log = tarpolyglot::tar_polyglot_log(stdout = "./logs/out", stderr = "./logs/err")
  )
)
} # }
```
