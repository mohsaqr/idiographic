test_that("graphical_var returns a well-formed gvar_result", {
  d <- synth_single(n_t = 100)
  gv <- graphical_var(d, vars = c("A", "B", "C"), id = "id",
                      day = "day", beep = "beep", n_lambda = 10, gamma = 0.5)
  expect_s3_class(gv, "gvar_result")
  expect_identical(gv$labels, c("A", "B", "C"))
  expect_equal(dim(gv$temporal), c(3L, 3L))
  expect_equal(dim(gv$PCC), c(3L, 3L))
  # PCC is symmetric with a zero diagonal
  expect_equal(gv$PCC, t(gv$PCC))
  expect_true(all(diag(gv$PCC) == 0))
})

test_that("degenerate (constant) variables are rejected with a clear message", {
  d <- synth_single(n_t = 60)
  d$C <- 1                                  # zero variance
  expect_error(
    graphical_var(d, vars = c("A", "B", "C"), id = "id", n_lambda = 5),
    "zero variance"
  )
})

test_that("graphical_var_each fits one network per subject and prints empty", {
  d <- synth_panel(n_id = 4, days = 2, beeps = 12)
  fits <- graphical_var_each(d, vars = c("A", "B", "C"), id = "id",
                             day = "day", beep = "beep", n_lambda = 8)
  expect_s3_class(fits, "gvar_list")
  expect_length(fits, 4L)
  expect_true(all(vapply(fits, inherits, logical(1), "gvar_result")))
  # empty-list print path must not error
  expect_output(print(structure(list(), class = "gvar_list")), "Subjects:")
})

test_that("fixed lambda_beta pins the temporal penalty (skips its EBIC grid)", {
  d <- synth_single(n_t = 120, seed = 13)
  vars <- c("A", "B", "C")
  # A fixed, larger penalty must give a sparser-or-equal temporal net than a
  # tiny one, and must not error.
  hi <- graphical_var(d, vars = vars, id = "id", lambda_beta = 0.3, n_lambda = 10)
  lo <- graphical_var(d, vars = vars, id = "id", lambda_beta = 1e-4, n_lambda = 10)
  expect_s3_class(hi, "gvar_result")
  expect_true(sum(hi$temporal != 0) <= sum(lo$temporal != 0))
  expect_error(graphical_var(d, vars = vars, id = "id", lambda_beta = -1))
})

test_that("fixed lambda_beta matches graphicalVAR's lambda_beta argument", {
  skip_if_not_installed("graphicalVAR")
  d <- synth_single(n_t = 150, seed = 17)
  vars <- c("A", "B", "C")
  ido <- graphical_var(d, vars = vars, id = "id", day = "day", beep = "beep",
                       lambda_beta = 0.1, gamma = 0.5, n_lambda = 30)
  ref <- suppressWarnings(graphicalVAR::graphicalVAR(
    d[, c(vars, "id", "day", "beep")], vars = vars,
    idvar = "id", dayvar = "day", beepvar = "beep",
    lambda_beta = 0.1, gamma = 0.5, nLambda = 30, verbose = FALSE
  ))
  expect_equal(ido$beta, ref$beta, tolerance = 1e-3, ignore_attr = TRUE)
  expect_equal(sum(ido$temporal != 0), sum(ref$beta[, -1] != 0))
})

test_that("multi-lag and bad mimic are handled", {
  d <- synth_single(n_t = 80)
  expect_error(graphical_var(d, vars = c("A", "B", "C"), id = "id", lags = 2),
               "lags")
  expect_warning(
    graphical_var(d, vars = c("A", "B", "C"), id = "id", n_lambda = 6,
                  mimic = "0.1.2"),
    "mimic"
  )
})

test_that(".glasso_fit accepts a matrix penalty (regularize_mat_kappa path)", {
  set.seed(3)
  X <- matrix(stats::rnorm(200 * 4), ncol = 4)
  S <- stats::cov(X)
  Rho <- matrix(0.1, 4, 4); diag(Rho) <- 0
  fit <- idionet:::.glasso_fit(S, Rho)
  # equals the scalar path when the matrix is constant off-diagonal, 0 on diag
  fit_scalar <- idionet:::.glasso_fit(S, 0.1, penalize.diagonal = FALSE)
  expect_equal(fit$wi, fit_scalar$wi, tolerance = 1e-8)
})

test_that("graphicalVAR API options match graphicalVAR", {
  skip_if_not_installed("graphicalVAR")
  d <- synth_single(n_t = 150, seed = 23)
  vars <- c("A", "B", "C")
  gv <- function(...) graphical_var(d, vars = vars, id = "id", n_lambda = 20, ...)
  rg <- function(...) suppressWarnings(graphicalVAR::graphicalVAR(
    d[, vars], vars = vars, nLambda = 20, verbose = FALSE, ...))

  # penalized likelihood
  expect_equal(gv(likelihood = "penalized")$beta,
               rg(likelihood = "penalized")$beta, tolerance = 1e-3,
               ignore_attr = TRUE)
  # separate lambda_min_beta
  expect_equal(gv(lambda_min_beta = 0.01)$beta,
               rg(lambda_min_beta = 0.01)$beta, tolerance = 1e-3,
               ignore_attr = TRUE)
  # custom kappa regularization mask (off-diagonal only)
  rk <- matrix(TRUE, 3, 3); diag(rk) <- FALSE; rk[1, 2] <- rk[2, 1] <- FALSE
  expect_equal(gv(regularize_mat_kappa = rk)$kappa,
               rg(regularize_mat_kappa = rk)$kappa, tolerance = 1e-3,
               ignore_attr = TRUE)
  # mask WITH a penalised diagonal must also match (diag was previously ignored)
  rk2 <- matrix(TRUE, 3, 3)
  expect_equal(gv(regularize_mat_kappa = rk2)$kappa,
               rg(regularize_mat_kappa = rk2)$kappa, tolerance = 1e-3,
               ignore_attr = TRUE)
})

test_that("graphical_var matches graphicalVAR to ~machine precision", {
  skip_if_not_installed("graphicalVAR")
  d <- synth_single(n_t = 150, seed = 11)
  vars <- c("A", "B", "C")
  gv <- graphical_var(d, vars = vars, id = "id", day = "day", beep = "beep",
                      n_lambda = 20, gamma = 0.5)
  ref <- suppressWarnings(graphicalVAR::graphicalVAR(
    d[, c(vars, "id", "day", "beep")], vars = vars,
    idvar = "id", dayvar = "day", beepvar = "beep",
    gamma = 0.5, nLambda = 20, verbose = FALSE
  ))
  expect_equal(gv$beta, ref$beta, tolerance = 1e-4, ignore_attr = TRUE)
  expect_equal(gv$kappa, ref$kappa, tolerance = 1e-4, ignore_attr = TRUE)
})

test_that("regularize_mat_beta penalty rows align (intercept prepended)", {
  # Direct test of .gvar_lambda_mat: the unpenalised intercept must be row 1,
  # and each predictor's custom penalty must land on its own row (rows 2..p+1),
  # not be shifted by appending the intercept at the bottom.
  p <- 3L
  M <- matrix(c(0, 1, 1,
                1, 0, 1,
                1, 1, 0), p, p, byrow = TRUE)   # penalise off-diagonal only
  lm <- idionet:::.gvar_lambda_mat(
    lambda_beta = 0.1, nX = p + 1L, nY = p,
    penalize_diagonal = TRUE, regularize_mat_beta = M
  )
  expect_equal(dim(lm), c(p + 1L, p))
  expect_true(all(lm[1L, ] == 0))                # intercept row unpenalised
  expect_equal(lm[-1L, ], 0.1 * t(M), ignore_attr = TRUE)  # predictors aligned
})
