# Regression tests for three defects fixed on 2026-11-22 (each stopped with an unclassed error on input its
# documentation accepts): compare() of a regression and a classification fit, edges() of per-person graphical
# VARs when one person's network has no edge, and importance(method = "permutation") of a fit_lm() fit.

test_that("compare() stacks a regression and a classification fit, NA where a metric does not apply", {
  linear <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day", scope = "individual")
  binary <- transform(srl, high_effort = as.integer(effort > 60))
  logistic <- fit_glm(binary, y = "high_effort", x = "efficacy", id = "name", family = "binomial",
                      time = "day", scope = "individual")
  both <- compare(linear, logistic)
  expect_s3_class(both, "data.frame")
  expect_identical(both$fit, c(1L, 2L))
  expect_identical(both$method, c("lm", "glm"))
  expect_true(all(c("rmse", "mae", "accuracy", "brier") %in% names(both)))
  # Each row carries its own fit's overall metrics, and NA for the other task's.
  lm_overall <- metrics(linear, overall = TRUE)
  glm_overall <- metrics(logistic, overall = TRUE)
  expect_equal(both$rmse[[1L]], lm_overall$rmse, tolerance = 1e-12)
  expect_equal(both$accuracy[[2L]], glm_overall$accuracy, tolerance = 1e-12)
  expect_true(is.na(both$accuracy[[1L]]) && is.na(both$brier[[1L]]))
  expect_true(is.na(both$rmse[[2L]]) && is.na(both$r_squared[[2L]]))
  # Same-task comparison is unchanged: no NA columns are introduced.
  expect_false(anyNA(compare(linear, linear)))
})

test_that("edges() of per-person graphical VARs keeps going when a person has no edge", {
  # The stacking helper: a person whose table has no rows contributes no rows.
  stub <- list(a = 1, b = 2)
  table_of <- function(v) {
    if (v == 1) data.frame(from = "A", to = "B", weight = 0.5)
    else data.frame(from = character(), to = character(), weight = numeric())
  }
  stacked <- idiographic:::.ido_stack_subject_tables(stub, table_of)
  expect_identical(stacked, data.frame(subject = "a", from = "A", to = "B", weight = 0.5))

  # End to end: on this panel persons 2 and 3 have no edge besides their self-loops.
  panel <- synth_panel(n_id = 3, days = 1, beeps = 55, seed = 904)
  each <- fit_graphical_var_each(panel, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
                                 n_lambda = 8, verbose = FALSE)
  per_person <- vapply(each, \(fit) nrow(edges(fit)), integer(1))
  expect_true(any(per_person == 0L))
  stacked_edges <- edges(each)
  expect_identical(nrow(stacked_edges), sum(per_person))
  expect_identical(names(stacked_edges), c("subject", "network", "from", "to", "weight"))
})

test_that("permutation importance of a fit_lm() fit equals the procedure written out", {
  set.seed(42)
  n <- 50L
  person <- data.frame(id = "p1", t = seq_len(n), x = stats::rnorm(n), z = stats::rnorm(n))
  person$y <- 2 * person$x + 0.5 * person$z + stats::rnorm(n, sd = 0.3)
  fit <- fit_lm(person, y = "y", x = c("x", "z"), id = "id", time = "t", scope = "individual",
                test_prop = 0.2)
  # By hand: the model on the first 40 occasions, the last 10 held out, shuffled in the package's order
  # (predictor by predictor, `repeats` shuffles each).
  train <- person[1:40, ]
  held <- person[41:50, ]
  model <- stats::lm(y ~ x + z, data = train)
  rmse <- function(rows) sqrt(mean((rows$y - stats::predict(model, newdata = rows))^2))
  repeats <- 4L
  set.seed(7)
  by_hand <- vapply(c("x", "z"), \(v) {
    mean(vapply(seq_len(repeats), \(r) {
      shuffled <- held
      shuffled[[v]] <- sample(shuffled[[v]])
      rmse(shuffled)
    }, numeric(1))) - rmse(held)
  }, numeric(1))
  set.seed(7)
  ours <- importance(fit, method = "permutation", repeats = repeats)
  expect_identical(nrow(ours), 2L)
  expect_equal(ours$importance[match(c("x", "z"), ours$variable)], unname(by_hand), tolerance = 1e-12)
  # x carries most of the signal.
  expect_identical(ours$variable[[1L]], "x")
})

test_that("permutation importance is exactly zero for a predictor constant in the held-out rows", {
  set.seed(43)
  n <- 50L
  person <- data.frame(id = "p1", t = seq_len(n), x = stats::rnorm(n), z = stats::rnorm(n))
  person$z[41:50] <- 0.25
  person$y <- person$x + person$z + stats::rnorm(n, sd = 0.3)
  fit <- fit_lm(person, y = "y", x = c("x", "z"), id = "id", time = "t", scope = "individual",
                test_prop = 0.2)
  set.seed(1)
  ours <- importance(fit, method = "permutation", repeats = 3L)
  expect_identical(ours$importance[ours$variable == "z"], 0)
})

test_that("permutation importance of a logistic fit_glm() fit runs on the probability scale", {
  binary <- transform(srl, high_effort = as.integer(effort > 60))
  logistic <- fit_glm(binary, y = "high_effort", x = "efficacy", id = "name", family = "binomial",
                      time = "day", scope = "individual")
  set.seed(1)
  ours <- importance(logistic, method = "permutation", repeats = 2L, subject = "Aisha")
  expect_identical(nrow(ours), 1L)
  expect_true(is.finite(ours$importance))
})

test_that("permutation importance refuses a stored model it cannot predict, with a class", {
  expect_error(idiographic:::.idio_unit_predict(structure(list(), class = "mystery"), data.frame(x = 1)),
               class = "idiographic_unsupported_model")
})
