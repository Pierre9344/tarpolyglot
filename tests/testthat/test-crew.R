# polyglot_controller() should return a crew controller with the isolation
# defaults. Constructing a controller does not launch workers.

test_that("polyglot_controller returns a crew controller", {
  ctrl <- polyglot_controller(workers = 3L)
  on.exit(try(ctrl$terminate(), silent = TRUE), add = TRUE)
  expect_s3_class(ctrl, "crew_class_controller")
})

test_that("isolation default is one task per worker", {
  ctrl <- polyglot_controller()
  on.exit(try(ctrl$terminate(), silent = TRUE), add = TRUE)
  # tasks_max = 1 => a worker is retired after a single task (fresh interpreter).
  expect_equal(ctrl$launcher$tasks_max, 1L)
})
