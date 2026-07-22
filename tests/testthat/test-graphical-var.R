test_that("graphical_var returns a well-formed gvar_result", {
  d <- synth_single(n_t = 100)
  gv <- fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
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
    fit_graphical_var(d, vars = c("A", "B", "C"), id = "id", n_lambda = 5),
    "zero/non-finite variance"
  )
})

test_that("graphical_var rejects non-numeric variables before scaling", {
  d <- synth_single(n_t = 60)
  d$A <- factor(rep(1:5, length.out = nrow(d)))
  expect_error(
    fit_graphical_var(d, vars = c("A", "B", "C"), id = "id", n_lambda = 5),
    "must be numeric"
  )
})

test_that("fit_graphical_var_each fits one network per subject and prints empty", {
  d <- synth_panel(n_id = 4, days = 2, beeps = 12)
  fits <- fit_graphical_var_each(d, vars = c("A", "B", "C"), id = "id",
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
  hi <- fit_graphical_var(d, vars = vars, id = "id", lambda_beta = 0.3, n_lambda = 10)
  lo <- fit_graphical_var(d, vars = vars, id = "id", lambda_beta = 1e-4, n_lambda = 10)
  expect_s3_class(hi, "gvar_result")
  expect_true(sum(hi$temporal != 0) <= sum(lo$temporal != 0))
  expect_error(fit_graphical_var(d, vars = vars, id = "id", lambda_beta = -1))
})

test_that("fixed lambda_beta matches graphicalVAR's lambda_beta argument", {
  skip_unless_equivalence()
  skip_if_not_installed("graphicalVAR")
  d <- synth_single(n_t = 150, seed = 17)
  vars <- c("A", "B", "C")
  ido <- fit_graphical_var(d, vars = vars, id = "id", day = "day", beep = "beep",
                       lambda_beta = 0.1, gamma = 0.5, n_lambda = 30)
  ref <- suppressWarnings(graphicalVAR::graphicalVAR(
    d[, c(vars, "id", "day", "beep")], vars = vars,
    idvar = "id", dayvar = "day", beepvar = "beep",
    lambda_beta = 0.1, gamma = 0.5, nLambda = 30, verbose = FALSE
  ))
  expect_equal(ido$beta, ref$beta, tolerance = 1e-3, ignore_attr = TRUE)
  expect_equal(sum(ido$temporal != 0), sum(ref$beta[, -1] != 0))
})

test_that("multi-lag fits expose coherent named temporal layers", {
  d <- synth_single(n_t = 80, seed = 41)
  vars <- c("A", "B", "C")
  fit <- fit_graphical_var(
    d, vars = vars, id = "id", day = "day", beep = "beep",
    lags = c(1, 2), lambda_beta = 0.08, lambda_kappa = 0.08
  )

  expect_identical(fit$lags, c(1L, 2L))
  expect_named(fit$temporal_layers, c("lag1", "lag2"))
  expect_named(fit$PDC_layers, c("lag1", "lag2"))
  expect_equal(dim(fit$beta), c(3L, 7L))
  expect_identical(colnames(fit$beta),
                   c("(Intercept)", "A_lag1", "B_lag1", "C_lag1",
                     "A_lag2", "B_lag2", "C_lag2"))
  expect_equal(fit$temporal, fit$temporal_layers$lag1)
  expect_setequal(names(unclass(fit)),
                  c("temporal_lag1", "temporal_lag2", "contemporaneous"))
  coef_table <- coefs(fit)
  expect_setequal(unique(coef_table$network),
                  c("temporal_lag1", "temporal_lag2", "contemporaneous"))
  expect_equal(sum(coef_table$network == "temporal_lag1"), 9L)
  expect_equal(sum(coef_table$network == "temporal_lag2"), 9L)
  expect_equal(fit$n_obs, 8L * (10L - 2L))

  expect_error(fit_graphical_var(d, vars = vars, lags = c(1, 1)), "duplicates")
  expect_error(fit_graphical_var(d, vars = vars, lags = 0), "positive integers")
})

test_that("unsupported legacy mimic modes error instead of claiming equivalence", {
  d <- synth_single(n_t = 80)
  expect_error(
    fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                      mimic = "0.1.2", n_lambda = 5),
    "not implemented.*only claims current-mode equivalence"
  )
})

test_that("prepared current/lag matrices reproduce the raw multi-lag fit", {
  d <- synth_single(n_t = 80, seed = 42)
  vars <- c("A", "B", "C")
  design <- idiographic:::.gvar_tsdata(
    d, vars, id = "id", day = "day", beep = "beep", scale = TRUE,
    center_within = TRUE, delete_missings = TRUE, lags = c(1, 2)
  )
  raw <- fit_graphical_var(
    d, vars = vars, id = "id", day = "day", beep = "beep", lags = c(1, 2),
    lambda_beta = 0.08, lambda_kappa = 0.08
  )
  prepared_design <- design[c("data_c", "data_l")]
  prepared <- fit_graphical_var(
    prepared_design, lambda_beta = 0.08, lambda_kappa = 0.08
  )

  expect_true(prepared$prepared_input)
  expect_identical(prepared$lags, c(1L, 2L))
  expect_equal(prepared$beta, raw$beta, tolerance = 1e-10)
  expect_equal(prepared$kappa, raw$kappa, tolerance = 1e-10)
  without_intercept <- fit_graphical_var(
    list(data_c = design$data_c,
         data_l = design$data_l[, -1L, drop = FALSE]),
    lambda_beta = 0.08, lambda_kappa = 0.08
  )
  expect_equal(without_intercept$beta, raw$beta, tolerance = 1e-10)
  expect_error(
    fit_graphical_var(prepared_design, id = "id",
                      lambda_beta = 0.08, lambda_kappa = 0.08),
    "cannot be applied"
  )
})

test_that("n_lambda and lambda minima accept tidy beta/kappa pairs", {
  d <- synth_single(n_t = 80, seed = 43)
  fit <- fit_graphical_var(
    d, vars = c("A", "B", "C"), id = "id",
    n_lambda = c(kappa = 4, beta = 3),
    lambda_min_ratio = c(kappa = 0.2, beta = 0.1),
    lambda_min_kappa = 0.4, maxit_in = 5, maxit_out = 5
  )

  expect_identical(fit$n_lambda, c(beta = 3L, kappa = 4L))
  expect_length(unique(fit$path$beta), 3L)
  expect_length(unique(fit$path$kappa), 4L)
  expect_equal(min(fit$path$beta) / max(fit$path$beta), 0.1,
               tolerance = 1e-12)
  expect_equal(min(fit$path$kappa) / max(fit$path$kappa), 0.4,
               tolerance = 1e-12)

  expect_identical(
    idiographic:::.gvar_pair_arg(c(3, 4), "n_lambda", integer = TRUE,
                                 lower = 2, upper = Inf),
    c(beta = 3L, kappa = 4L)
  )
  expect_error(fit_graphical_var(d, vars = c("A", "B", "C"),
                                 n_lambda = c(beta = 3, other = 4)),
               "exactly `beta` and `kappa`")
  expect_error(fit_graphical_var(d, vars = c("A", "B", "C"),
                                 lambda_min_ratio = 1),
               "lambda_min_ratio")
})

test_that("iteration limits are honored and exposed as diagnostics", {
  d <- synth_single(n_t = 80, seed = 44)
  fit <- fit_graphical_var(
    d, vars = c("A", "B", "C"), id = "id",
    lambda_beta = 0.02, lambda_kappa = 0.02,
    maxit_in = 1, maxit_out = 1
  )
  expect_identical(fit$convergence$maxit_in, 1L)
  expect_identical(fit$convergence$maxit_out, 1L)
  expect_lte(fit$convergence$outer_iterations, 1L)
  expect_true(all(fit$convergence$inner_iterations <= 1L))
  expect_error(fit_graphical_var(d, vars = c("A", "B", "C"), maxit_in = 1.5),
               "maxit_in")
})

test_that("EBIC ties prefer lower kappa then lower beta within tolerance", {
  grid <- data.frame(
    kappa = c(0.2, 0.1, 0.1, 0.05),
    beta = c(0.2, 0.2, 0.1, 0.4),
    ebic = c(10, 10.00005, 10.00005, 10.1)
  )
  expect_identical(idiographic:::.gvar_select_ebic(grid, 1e-4), 3L)
  expect_identical(idiographic:::.gvar_select_ebic(grid, 0), 1L)
  expect_error(idiographic:::.gvar_select_ebic(transform(grid, ebic = NA_real_)),
               "No finite EBIC")
})

test_that("missing values and missing beeps have explicit lag-pair behavior", {
  d <- synth_single(n_t = 80, seed = 45)
  vars <- c("A", "B", "C")
  d$A[d$day == 1 & d$beep == 4] <- NA_real_
  fit <- fit_graphical_var(
    d, vars = vars, id = "id", day = "day", beep = "beep",
    lambda_beta = 0.08, lambda_kappa = 0.08, delete_missings = TRUE
  )
  expect_equal(fit$n_obs, 70L) # missing current row and its next lag-pair row
  expect_error(
    fit_graphical_var(d, vars = vars, id = "id", day = "day", beep = "beep",
                      lambda_beta = 0.08, lambda_kappa = 0.08,
                      delete_missings = FALSE),
    "requires complete finite lag pairs"
  )

  complete <- synth_single(n_t = 80, seed = 45)
  gap <- complete[!(complete$day == 1 & complete$beep == 4), ]
  gap_fit <- fit_graphical_var(
    gap, vars = vars, id = "id", day = "day", beep = "beep",
    lambda_beta = 0.08, lambda_kappa = 0.08
  )
  expect_equal(gap_fit$n_obs, 70L) # beep 5 is not joined to nonconsecutive beep 3
})

test_that(".glasso_fit accepts a matrix penalty (regularize_mat_kappa path)", {
  set.seed(3)
  X <- matrix(stats::rnorm(200 * 4), ncol = 4)
  S <- stats::cov(X)
  Rho <- matrix(0.1, 4, 4); diag(Rho) <- 0
  fit <- idiographic:::.glasso_fit(S, Rho)
  # equals the scalar path when the matrix is constant off-diagonal, 0 on diag
  fit_scalar <- idiographic:::.glasso_fit(S, 0.1, penalize.diagonal = FALSE)
  expect_equal(fit$wi, fit_scalar$wi, tolerance = 1e-8)
})

test_that("graphicalVAR API options match graphicalVAR", {
  skip_unless_equivalence()
  skip_if_not_installed("graphicalVAR")
  d <- synth_single(n_t = 150, seed = 23)
  vars <- c("A", "B", "C")
  gv <- function(...) fit_graphical_var(d, vars = vars, id = "id", n_lambda = 20, ...)
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
  skip_unless_equivalence()
  skip_if_not_installed("graphicalVAR")
  d <- synth_single(n_t = 150, seed = 11)
  vars <- c("A", "B", "C")
  gv <- fit_graphical_var(d, vars = vars, id = "id", day = "day", beep = "beep",
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
  lm <- idiographic:::.gvar_lambda_mat(
    lambda_beta = 0.1, nX = p + 1L, nY = p,
    penalize_diagonal = TRUE, regularize_mat_beta = M
  )
  expect_equal(dim(lm), c(p + 1L, p))
  expect_true(all(lm[1L, ] == 0))                # intercept row unpenalised
  expect_equal(lm[-1L, ], 0.1 * t(M), ignore_attr = TRUE)  # predictors aligned

  # With multiple lags, penalize_diagonal = FALSE unpenalizes the AR diagonal
  # in every lag block, not only lag 1.
  lm_multi <- idiographic:::.gvar_lambda_mat(
    lambda_beta = 0.1, nX = 1L + 2L * p, nY = p,
    penalize_diagonal = FALSE, regularize_mat_beta = NULL
  )
  ar_cells <- cbind(2:(1L + 2L * p), rep(seq_len(p), 2L))
  expected_multi <- matrix(0.1, 1L + 2L * p, p)
  expected_multi[1L, ] <- 0
  expected_multi[ar_cells] <- 0
  expect_equal(lm_multi, expected_multi)
})
