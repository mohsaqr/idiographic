test_that("build_var returns a tidy OLS VAR result", {
  d <- synth_single(n_t = 100, vars = c("A", "B", "C"), seed = 201)
  fit <- build_var(d, vars = c("A", "B", "C"), id = "id",
                   day = "day", beep = "beep", scale = FALSE)

  expect_s3_class(fit, "var_result")
  expect_s3_class(fit, "netobject_group")
  expect_s3_class(fit, "cograph_group")
  expect_named(as_netobject(fit), c("temporal", "contemporaneous"))
  expect_equal(dim(fit$temporal), c(3L, 3L))
  expect_equal(dim(fit$PCC), c(3L, 3L))
  expect_equal(fit$PCC, t(fit$PCC), tolerance = 1e-12)
  expect_true(all(diag(fit$PCC) == 0))

  e <- edges(fit)
  expect_named(e, c("network", "from", "to", "weight"))
  cf <- coefs(fit)
  expect_named(cf, c("network", "from", "to", "weight"))
  expect_equal(sum(cf$network == "temporal"), 9L)
  nd <- nodes(fit)
  expect_named(nd, c("network", "node", "strength", "out_strength",
                     "in_strength", "self"))
})

test_that("build_var is cell-equivalent to stats::lm.fit", {
  d <- synth_single(n_t = 120, vars = c("A", "B", "C"), seed = 202)
  vars <- c("A", "B", "C")
  fit <- build_var(d, vars = vars, id = "id", day = "day", beep = "beep",
                   scale = FALSE, center_within = FALSE)
  ts <- idiographic:::.gvar_tsdata(
    d, vars = vars, id = "id", day = "day", beep = "beep",
    scale = FALSE, center_within = FALSE, delete_missings = TRUE
  )
  ref <- stats::lm.fit(x = ts$data_l, y = ts$data_c)
  beta <- t(ref$coefficients)
  rownames(beta) <- vars
  colnames(beta) <- colnames(ts$data_l)
  residuals <- ts$data_c - ts$data_l %*% ref$coefficients
  residual_cov <- stats::cov(residuals)
  dimnames(residual_cov) <- list(vars, vars)

  expect_equal(fit$beta, beta, tolerance = 1e-12, ignore_attr = TRUE)
  expect_equal(fit$temporal, beta[, -1L], tolerance = 1e-12,
               ignore_attr = TRUE)
  expect_equal(fit$residual_cov, residual_cov, tolerance = 1e-12,
               ignore_attr = TRUE)
})

test_that("build_var respects subject filtering and rejects unsupported lags", {
  d <- synth_panel(n_id = 4, days = 2, beeps = 10, vars = c("A", "B"),
                   seed = 203)
  one <- build_var(d, vars = c("A", "B"), id = "id", day = "day",
                   beep = "beep", subject = 2, scale = FALSE)
  direct <- build_var(subset(d, id == 2), vars = c("A", "B"), id = "id",
                      day = "day", beep = "beep", scale = FALSE)
  expect_equal(one$temporal, direct$temporal, tolerance = 1e-12)
  expect_error(build_var(d, vars = c("A", "B"), id = "id", lags = 2),
               "lags = 1")
})

test_that("build_var rejects rank-deficient and non-numeric designs clearly", {
  set.seed(205)
  d <- data.frame(
    id = 1,
    day = rep(1:4, each = 12),
    beep = rep(1:12, 4),
    A = stats::rnorm(48),
    B = stats::rnorm(48)
  )
  d$C <- d$A + d$B
  expect_error(
    build_var(d, vars = c("A", "B", "C"), id = "id", day = "day",
              beep = "beep", scale = FALSE),
    "rank-deficient"
  )

  d$C <- factor(rep(1:4, length.out = nrow(d)))
  expect_error(
    build_var(d, vars = c("A", "B", "C"), id = "id", day = "day",
              beep = "beep", scale = FALSE),
    "must be numeric"
  )
})

test_that("build_var_each is subject-by-subject equivalent to build_var", {
  d <- synth_panel(n_id = 4, days = 2, beeps = 12, vars = c("A", "B", "C"),
                   seed = 204)
  fits <- build_var_each(d, vars = c("A", "B", "C"), id = "id",
                         day = "day", beep = "beep", scale = FALSE)

  expect_s3_class(fits, "var_list")
  expect_length(fits, 4L)
  expect_true(all(vapply(fits, inherits, logical(1), "var_result")))

  for (subject_id in names(fits)) {
    direct <- build_var(d, vars = c("A", "B", "C"), id = "id",
                        day = "day", beep = "beep",
                        subject = as.integer(subject_id), scale = FALSE)
    expect_equal(fits[[subject_id]]$beta, direct$beta, tolerance = 1e-12,
                 ignore_attr = TRUE, info = paste("beta subject", subject_id))
    expect_equal(fits[[subject_id]]$PCC, direct$PCC, tolerance = 1e-12,
                 ignore_attr = TRUE, info = paste("PCC subject", subject_id))
  }

  expect_output(print(fits), "Idiographic OLS VARs")
  expect_output(print(structure(list(), class = "var_list")), "Subjects:")
})
