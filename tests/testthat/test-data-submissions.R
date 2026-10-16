test_that("submissions is a balanced binary panel with two types", {
  expect_equal(dim(submissions), c(3200L, 5L))
  expect_named(submissions, c("learner", "day", "type", "motivation", "submitted"))
  expect_setequal(unique(submissions$submitted), c(0, 1))
  expect_setequal(unique(submissions$type), c("engaged", "avoidant"))
  expect_true(all(table(submissions$learner) == 80L))
})
