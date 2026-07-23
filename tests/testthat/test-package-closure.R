.fake_mplus_mlvar <- function(data, vars) {
  p <- length(vars)
  beta <- array(seq_len(p * p) / 10, c(p, p, 1L),
                dimnames = list(vars, vars, "lag1"))
  theta <- matrix(c(1, .2, .2, 1), p, p,
                  dimnames = list(vars, vars))
  omega <- matrix(c(1, -.1, -.1, 1), p, p,
                  dimnames = list(vars, vars))
  structure(list(
    input = list(estimator = "Mplus"),
    data = data,
    results = list(
      Beta = list(
        mean = beta, SD = beta / 10, lower = beta - .05,
        upper = beta + .05, P = beta * 0 + .01
      ),
      Theta = list(pcor = list(mean = theta)),
      Omega_mu = list(pcor = list(mean = omega))
    ),
    output = list(summaries = list(Observations = nrow(data)))
  ), class = "mlVAR")
}

test_that("Mplus wrapper forwards its complete public contract and converts output", {
  d <- synth_panel(n_id = 4, days = 2, beeps = 8,
                   vars = c("A", "B"), seed = 901)
  capture <- new.env(parent = emptyenv())
  work <- tempfile("idiographic-mplus-contract-")
  dir.create(work)
  file.create(file.path(work, ".idiographic-workdir-sentinel"))
  local_mocked_bindings(
    .mlvar_mplus_detect = function() "mock-mplus",
    .mlvar_mplus_call = function(args) {
      capture$args <- args
      capture$wd <- getwd()
      capture$in_workdir <- file.exists(".idiographic-workdir-sentinel")
      .fake_mplus_mlvar(args$data, args$vars)
    },
    .package = "idiographic"
  )
  signs <- matrix(c(0, 1, -1, 0), 2, 2)

  fit <- fit_mlvar_mplus(
    d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    temporal = "orthogonal", contemporaneous = "correlated",
    nCores = 3, scale = FALSE, scaleWithin = TRUE,
    MplusSave = FALSE, MplusName = "contract", iterations = "(4321)",
    chains = 4, signs = signs, workdir = work, verbose = FALSE,
    extra_control = 17
  )

  expect_true(capture$in_workdir)
  expect_identical(capture$args$estimator, "Mplus")
  expect_identical(capture$args$idvar, "id")
  expect_identical(capture$args$dayvar, "day")
  expect_identical(capture$args$beepvar, "beep")
  expect_identical(capture$args$lags, 1L)
  expect_identical(capture$args$temporal, "orthogonal")
  expect_identical(capture$args$contemporaneous, "correlated")
  expect_identical(capture$args$nCores, 3)
  expect_false(capture$args$scale)
  expect_true(capture$args$scaleWithin)
  expect_false(capture$args$MplusSave)
  expect_identical(capture$args$MplusName, "contract")
  expect_identical(capture$args$iterations, "(4321)")
  expect_identical(capture$args$chains, 4)
  expect_identical(capture$args$signs, signs)
  expect_identical(capture$args$extra_control, 17)

  expect_s3_class(fit, "net_mplus")
  expect_equal(fit$temporal$weights,
               .fake_mplus_mlvar(d, c("A", "B"))$results$Beta$mean[, , 1L])
  expect_equal(unname(diag(fit$contemporaneous$weights)), c(0, 0))
  expect_equal(unname(diag(fit$between$weights)), c(0, 0))
  expect_identical(attr(fit, "config")$mplus_command, "mock-mplus")
  expect_identical(equivalence(fit)$status, "delegated")
})

test_that("Bayesian burn-in and thinning controls determine retained draws", {
  d <- synth_panel(n_id = 10, days = 2, beeps = 10,
                   vars = c("A", "B"), seed = 902)

  var_fit <- fit_var_bayes(
    d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    n_iter = 120, n_burnin = 20, n_chains = 2, thin = 5, seed = 902
  )
  expect_identical(attr(var_fit, "model")$mcmc$n_burnin, 20)
  expect_identical(attr(var_fit, "model")$mcmc$thin, 5)
  expect_identical(attr(var_fit, "model")$mcmc$n_draws, 40L)

  mlvar_fit <- fit_mlvar_bayes(
    d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    n_iter = 120, n_burnin = 20, n_chains = 2, thin = 5, seed = 902
  )
  expect_identical(attr(mlvar_fit, "mcmc")$n_burnin, 20)
  expect_identical(attr(mlvar_fit, "mcmc")$thin, 5)
  expect_identical(attr(mlvar_fit, "mcmc")$n_draws, 40L)
})

test_that("parallel native mlVAR is numerically identical to one-core fitting", {
  skip_if_not_installed("lme4")
  d <- synth_panel(n_id = 10, days = 2, beeps = 10,
                   vars = c("A", "B", "C"), seed = 903)
  args <- list(data = d, vars = c("A", "B", "C"), id = "id",
               day = "day", beep = "beep", scale = FALSE)
  serial <- suppressWarnings(do.call(fit_mlvar, c(args, list(nCores = 1))))
  parallel <- suppressWarnings(do.call(fit_mlvar, c(args, list(nCores = 2))))

  for (network in c("temporal", "contemporaneous", "between")) {
    expect_equal(serial[[network]]$weights, parallel[[network]]$weights,
                 tolerance = 1e-12)
  }
  expect_identical(attr(parallel, "config")$nCores, 2L)
})

test_that("native idiographic ML linear engines equal base-R reference engines", {
  set.seed(907)
  d <- data.frame(
    id = rep(1:4, each = 40), beep = rep(seq_len(40), 4),
    x1 = rnorm(160), x2 = rnorm(160)
  )
  d$y <- .4 + .7 * d$x1 - .3 * d$x2 + rnorm(160, sd = .2)
  train_rows <- rep(c(rep(TRUE, 32), rep(FALSE, 8)), 4)

  fit <- fit_ml(
    d, outcome = "y", predictors = c("x1", "x2"), id = "id",
    beep = "beep", task = "regression", model = "linear",
    compare = "pooled", test_prop = .2, standardize = FALSE,
    keep_fits = TRUE
  )
  reference <- stats::lm.fit(
    cbind("(Intercept)" = 1,
          as.matrix(d[train_rows, c("x1", "x2")])),
    d$y[train_rows]
  )$coefficients
  local <- fit$fits[["pooled:linear:native"]]$beta
  expect_equal(unname(local), unname(reference), tolerance = 1e-12)

  d$class <- factor(ifelse(.8 * d$x1 - .5 * d$x2 + rnorm(160) > 0,
                           "yes", "no"), levels = c("no", "yes"))
  class_fit <- fit_ml(
    d, outcome = "class", predictors = c("x1", "x2"), id = "id",
    beep = "beep", task = "classification", model = "logistic",
    compare = "pooled", test_prop = .2, standardize = FALSE,
    keep_fits = TRUE
  )
  y <- as.integer(d$class[train_rows] == "yes")
  logistic_reference <- suppressWarnings(stats::glm.fit(
    cbind("(Intercept)" = 1,
          as.matrix(d[train_rows, c("x1", "x2")])),
    y, family = stats::binomial()
  ))$coefficients
  logistic_local <- class_fit$fits[["pooled:logistic:native"]]$beta
  expect_equal(unname(logistic_local), unname(logistic_reference),
               tolerance = 1e-12)
})
