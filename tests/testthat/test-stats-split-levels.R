test_that("split_levels() adds person means and deviations that sum to the score", {
  out <- split_levels(srl, id = "name", vars = c("efficacy", "effort"))
  expect_true(all(c("efficacy_within", "efficacy_between",
                    "effort_within", "effort_between") %in% names(out)))
  expect_equal(nrow(out), nrow(srl))
  ok <- is.finite(out$efficacy)
  expect_equal(out$efficacy_within[ok] + out$efficacy_between[ok],
               out$efficacy[ok], tolerance = sqrt(.Machine$double.eps))
  # The between part is each person's mean; the within part averages zero.
  aisha <- subset(out, name == "Aisha")
  expect_equal(unique(aisha$efficacy_between),
               mean(aisha$efficacy, na.rm = TRUE))
  expect_equal(mean(aisha$efficacy_within, na.rm = TRUE), 0,
               tolerance = sqrt(.Machine$double.eps))
  expect_identical(split_wb(srl, id = "name", vars = "effort"),
                   split_levels(srl, id = "name", vars = "effort"))
})
