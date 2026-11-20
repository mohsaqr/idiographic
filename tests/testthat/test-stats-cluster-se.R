# Pooled and subgroup models stack many occasions per person; their standard
# errors are clustered on the person. The comparisons of those standard errors
# with the CR1 sandwich written out are in tests/equivalence/test-fit-lm.R.

cluster_panel <- function(seed = 11L, n_id = 30L, n_time = 40L) {
  set.seed(seed)
  id <- rep(seq_len(n_id), each = n_time)
  person_level <- stats::rnorm(n_id, sd = 1.5)[id]
  x <- person_level + stats::rnorm(n_id * n_time)
  y <- 0.4 * x + person_level + stats::rnorm(n_id * n_time)
  data.frame(id = id, t = rep(seq_len(n_time), n_id), x = x, y = y,
             event = stats::rbinom(n_id * n_time, 1, stats::plogis(0.5 * x)))
}

test_that("coefs() filters by term and rejects unknown terms", {
  d <- cluster_panel()
  fit <- fit_lm(d, y = "y", x = "x", id = "id", time = "t", scope = "both")
  only_x <- coefs(fit, scope = "individual", term = "x")
  expect_true(all(only_x$term == "x"))
  expect_equal(nrow(only_x), 30L)
  expect_error(coefs(fit, term = "nope"), "No such term")
})
