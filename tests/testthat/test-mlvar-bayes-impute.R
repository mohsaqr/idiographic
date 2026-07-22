# Within-model imputation (data augmentation) for fit_mlvar_bayes.

make_panel <- function(n_id = 15, n_t = 40, seed = 1, miss = 0) {
  set.seed(seed)
  Bm <- matrix(c(0.35, 0.10, 0.05, 0.30), 2, 2, byrow = TRUE)
  d <- do.call(rbind, lapply(seq_len(n_id), function(i) {
    mu <- rnorm(2, 0, 0.4); Bi <- Bm + matrix(rnorm(4, 0, 0.06), 2, 2)
    y <- matrix(0, n_t, 2)
    for (t in 2:n_t) y[t, ] <- mu + Bi %*% (y[t - 1, ] - mu) + rnorm(2)
    data.frame(id = i, beep = seq_len(n_t), V1 = y[, 1], V2 = y[, 2])
  }))
  if (miss > 0) {
    d$V1[runif(nrow(d)) < miss] <- NA
    d$V2[runif(nrow(d)) < miss] <- NA
  }
  d
}

test_that("impute=TRUE equals impute=FALSE on complete data (no cells to fill)", {
  skip_if_not_installed("corpcor")
  d <- make_panel(n_id = 14, n_t = 35, seed = 4)   # >= 2K+1 = 13 for p = 2
  a <- fit_mlvar_bayes(d, vars = c("V1", "V2"), id = "id", beep = "beep",
                         temporal = "random", impute = TRUE,  n_iter = 800,
                         n_chains = 1, seed = 9)
  b <- fit_mlvar_bayes(d, vars = c("V1", "V2"), id = "id", beep = "beep",
                         temporal = "random", impute = FALSE, n_iter = 800,
                         n_chains = 1, seed = 9)
  expect_equal(attr(a, "matrices")$B, attr(b, "matrices")$B, tolerance = 1e-10)
  expect_true(attr(a, "imputed"))
  expect_false(attr(b, "imputed"))
})

test_that("impute=TRUE runs under missingness and recovers the transition matrix", {
  skip_if_not_installed("corpcor")
  d <- make_panel(n_id = 25, n_t = 40, seed = 2, miss = 0.25)
  expect_true(anyNA(d$V1))
  fit <- fit_mlvar_bayes(d, vars = c("V1", "V2"), id = "id", beep = "beep",
                           temporal = "random", impute = TRUE, n_iter = 1200,
                           n_chains = 2, seed = 3)
  B <- attr(fit, "matrices")$B
  true_B <- matrix(c(0.35, 0.10, 0.05, 0.30), 2, 2, byrow = TRUE)
  expect_lt(max(abs(B - true_B)), 0.12)
  expect_lt(attr(fit, "max_psr"), 1.15)
  expect_identical(equivalence(fit)$status, "validated_recovery")
})

test_that("impute=TRUE requires temporal='random'", {
  skip_if_not_installed("corpcor")
  d <- make_panel(n_id = 10, n_t = 30, seed = 1, miss = 0.2)
  expect_error(
    fit_mlvar_bayes(d, vars = c("V1", "V2"), id = "id", beep = "beep",
                      temporal = "fixed", impute = TRUE, n_iter = 300),
    "requires temporal")
})

test_that("imputation handles absent-occasion rows (gap grid)", {
  skip_if_not_installed("corpcor")
  # drop whole occasions for some subjects -> grid must reinsert + impute them
  d <- make_panel(n_id = 20, n_t = 40, seed = 5)
  d <- d[!(d$id %% 2 == 0 & d$beep %in% c(10, 11, 25)), ]   # absent rows
  fit <- fit_mlvar_bayes(d, vars = c("V1", "V2"), id = "id", beep = "beep",
                           temporal = "random", impute = TRUE, n_iter = 900,
                           n_chains = 1, seed = 7)
  expect_s3_class(fit, "net_mlvar_bayes")
  expect_true(all(is.finite(attr(fit, "matrices")$B)))
  expect_identical(equivalence(fit)$status, "validated_recovery")
})
