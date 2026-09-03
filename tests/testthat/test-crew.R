# polyglot_controller() should return a crew controller with the isolation
# defaults. Constructing a controller does not launch workers.
#
# `crew` builds every controller through nanonext's TLS layer: crew_tls()
# defaults to `validate = TRUE`, and that validation calls
# nanonext::tls_config() as a self-test whatever the TLS `mode`, so it runs even
# for the no-TLS default polyglot_controller() uses. Where nanonext links a
# system NNG built without TLS support, rather than compiling its bundled copy,
# that self-test fails with "Not supported" and no controller can be
# constructed. That is a property of the host installation rather than of
# tarpolyglot, and nothing in this package can work around it, so the tests that
# need a real controller skip there instead of failing the check.
skip_if_no_crew_tls <- function() {
  testthat::skip_if_not(
    .tp_crew_tls_available(),
    "nanonext has no usable TLS layer, so crew cannot build a controller"
  )
}

test_that("polyglot_controller returns a crew controller", {
  skip_if_no_crew_tls()
  ctrl <- polyglot_controller(workers = 3L)
  on.exit(try(ctrl$terminate(), silent = TRUE), add = TRUE)
  expect_s3_class(ctrl, "crew_class_controller")
})

test_that("isolation default is one task per worker", {
  skip_if_no_crew_tls()
  ctrl <- polyglot_controller()
  on.exit(try(ctrl$terminate(), silent = TRUE), add = TRUE)
  # tasks_max = 1 => a worker is retired after a single task (fresh interpreter).
  expect_equal(ctrl$launcher$tasks_max, 1L)
})

test_that("polyglot_controller reports an unusable crew TLS layer", {
  skip_if_not_installed("testthat", "3.2.0")
  # Simulate the platform CRAN saw: nanonext with no usable TLS layer, so
  # crew's self-test rejects every controller.
  local_mocked_bindings(
    crew_controller_local = function(...) stop("9 | Not supported"),
    crew_tls = function(...) stop("9 | Not supported"),
    .package = "crew"
  )
  expect_error(polyglot_controller(), "could not create a `crew` controller",
    fixed = TRUE)
  # the underlying cause is kept, not swallowed
  expect_error(polyglot_controller(), "Not supported")
})

test_that("an unrelated crew error is passed through unchanged", {
  skip_if_not_installed("testthat", "3.2.0")
  skip_if_no_crew_tls()
  local_mocked_bindings(
    crew_controller_local = function(...) stop("some other crew problem"),
    .package = "crew"
  )
  expect_error(polyglot_controller(), "some other crew problem")
})
