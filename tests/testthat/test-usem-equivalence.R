fit_lavaan_equivalent <- function(syntax, data, estimator = "ml") {
  lavaan::lavaan(
    model = paste(syntax, collapse = "\n"),
    data = data,
    model.type = "sem",
    missing = "fiml",
    estimator = estimator,
    int.ov.free = FALSE,
    int.lv.free = TRUE,
    auto.fix.first = TRUE,
    auto.var = TRUE,
    auto.cov.lv.x = TRUE,
    auto.th = TRUE,
    auto.delta = TRUE,
    auto.cov.y = FALSE,
    auto.fix.single = TRUE,
    warn = FALSE
  )
}

extract_lavaan_usem_mats <- function(fit, vars) {
  lag_names <- paste0(vars, "lag")
  all_names <- c(lag_names, vars)
  std <- lavaan::lavInspect(fit, "std")
  beta <- std$beta
  psi <- std$psi

  coef_mat <- matrix(0, length(vars), 2L * length(vars),
                     dimnames = list(vars, all_names))
  coef_mat[vars, all_names] <- beta[vars, all_names, drop = FALSE]
  temporal <- coef_mat[, lag_names, drop = FALSE]
  colnames(temporal) <- vars
  contemporaneous <- coef_mat[, vars, drop = FALSE]
  diag(contemporaneous) <- 0

  residual_cov <- matrix(0, length(vars), length(vars),
                         dimnames = list(vars, vars))
  residual_cov[vars, vars] <- psi[vars, vars, drop = FALSE]
  diag(residual_cov) <- 0

  list(temporal = temporal,
       contemporaneous = contemporaneous,
       residual_cov = residual_cov)
}

expect_mats_equal_cellwise <- function(actual, expected, tolerance, label) {
  expect_equal(dim(actual), dim(expected), info = paste(label, "dim"))
  for (i in seq_len(nrow(expected))) {
    for (j in seq_len(ncol(expected))) {
      cell <- sprintf("%s[%s,%s]", label, rownames(expected)[i],
                      colnames(expected)[j])
      if (is.na(actual[i, j]) && is.na(expected[i, j])) next
      expect_true(abs(actual[i, j] - expected[i, j]) < tolerance, info = cell)
    }
  }
}

test_that("standardized non-default uSEM remains direct lavaan engine-equivalent", {
  skip_unless_equivalence()
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 2, days = 3, beeps = 14,
                   vars = c("A", "B", "C"), seed = 103)
  vars <- c("A", "B", "C")
  fit <- fit_usem(
    d, vars = vars, id = "id", day = "day", beep = "beep",
    temporal = "all", contemporaneous = c("B ~ A", "C ~ B"),
    residual_cov = TRUE, standardize = TRUE, estimator = "mlr"
  )
  prepared <- idiographic:::.gimme_prepare_data(
    d, vars = vars, id = "id", time = NULL, standardize = TRUE,
    exogenous = NULL, day = "day"
  )
  refs <- lapply(seq_along(prepared), function(i) {
    direct <- fit_lavaan_equivalent(fit$syntax, prepared[[i]],
                                    estimator = "mlr")
    extract_lavaan_usem_mats(direct, vars)
  })
  mean_mat <- function(name) {
    Reduce("+", lapply(refs, `[[`, name)) / length(refs)
  }
  expect_mats_equal_cellwise(fit$temporal, mean_mat("temporal"), 1e-10,
                             "standardized_temporal")
  expect_mats_equal_cellwise(fit$contemporaneous,
                             mean_mat("contemporaneous"), 1e-10,
                             "standardized_contemporaneous")
  expect_mats_equal_cellwise(fit$residual_cov, mean_mat("residual_cov"),
                             1e-10, "standardized_residual_cov")
  expect_identical(equivalence(fit)$status, "validated")
})

test_that("fixed fit_usem is cell-equivalent to direct lavaan for one subject", {
  skip_unless_equivalence()
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 1, days = 4, beeps = 14, vars = c("A", "B", "C"),
                   seed = 101)
  vars <- c("A", "B", "C")
  fit <- fit_usem(d, vars = vars, id = "id", day = "day", beep = "beep",
                    temporal = "all", contemporaneous = c("B ~ A", "C ~ B"),
                    residual_cov = TRUE)
  prepared <- idiographic:::.gimme_prepare_data(
    d, vars = vars, id = "id", time = NULL, standardize = FALSE,
    exogenous = NULL, day = "day"
  )[[1L]]
  ref <- fit_lavaan_equivalent(fit$syntax, prepared)
  mats <- extract_lavaan_usem_mats(ref, vars)

  subj <- fit$subjects[[1L]]
  expect_mats_equal_cellwise(subj$temporal, mats$temporal, 1e-10, "temporal")
  expect_mats_equal_cellwise(subj$contemporaneous, mats$contemporaneous,
                             1e-10, "contemporaneous")
  expect_mats_equal_cellwise(subj$residual_cov, mats$residual_cov,
                             1e-10, "residual_cov")
})

test_that("fixed fit_usem averages direct lavaan subject matrices", {
  skip_unless_equivalence()
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 3, days = 3, beeps = 12, vars = c("A", "B"),
                   seed = 102)
  vars <- c("A", "B")
  fit <- fit_usem(d, vars = vars, id = "id", day = "day", beep = "beep",
                    temporal = "ar", contemporaneous = "B ~ A",
                    residual_cov = TRUE)
  prepared <- idiographic:::.gimme_prepare_data(
    d, vars = vars, id = "id", time = NULL, standardize = FALSE,
    exogenous = NULL, day = "day"
  )
  refs <- lapply(prepared, function(dat) {
    mats <- extract_lavaan_usem_mats(fit_lavaan_equivalent(fit$syntax, dat),
                                     vars)
    mats
  })
  mean_mat <- function(name) {
    mats <- lapply(refs, `[[`, name)
    Reduce("+", mats) / length(mats)
  }

  expect_mats_equal_cellwise(fit$temporal, mean_mat("temporal"), 1e-10,
                             "temporal_avg")
  expect_mats_equal_cellwise(fit$contemporaneous, mean_mat("contemporaneous"),
                             1e-10, "contemporaneous_avg")
  expect_mats_equal_cellwise(fit$residual_cov, mean_mat("residual_cov"),
                             1e-10, "residual_cov_avg")
})
