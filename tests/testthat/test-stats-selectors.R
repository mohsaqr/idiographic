
test_that("a predictor constant for some persons is reported, naming them", {
  set.seed(7)
  n <- 40
  d <- rbind(
    data.frame(id = "flat", t = seq_len(n), a = 5, y = stats::rnorm(n)),
    data.frame(id = "p2", t = seq_len(n), a = stats::rnorm(n), y = stats::rnorm(n)),
    data.frame(id = "p3", t = seq_len(n), a = stats::rnorm(n), y = stats::rnorm(n)))
  expect_warning(
    fit_lm(d, y = "y", x = "a", id = "id", time = "t", scope = "individual"),
    "a \\(flat\\)", class = "idiographic_constant_predictor")

  # Pooled models are unaffected, and a clean panel raises nothing.
  expect_no_warning(fit_lm(d, y = "y", x = "a", id = "id", time = "t",
                           scope = "pooled"))
  clean <- subset(d, id != "flat")
  expect_no_warning(fit_lm(clean, y = "y", x = "a", id = "id", time = "t",
                           scope = "individual"))
})

test_that("scope accepts a vector of levels, equivalent to the shorthands", {
  d <- subset(srl, name %in% c("Aisha", "Alice", "Bob"))
  a <- fit_lm(d, y = "effort", x = "efficacy", id = "name", time = "day",
              scope = c("pooled", "individual"))
  b <- fit_lm(d, y = "effort", x = "efficacy", id = "name", time = "day",
              scope = "both")
  expect_equal(coefs(a), coefs(b))
  expect_error(fit_lm(d, y = "effort", x = "efficacy", id = "name",
                      scope = c("pooled", "nope")), "Unknown scope")
})
