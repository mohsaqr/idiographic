test_that("graphical VAR matches the upstream argument matrix", {
  skip_unless_equivalence()
  skip_if_not_installed("graphicalVAR", minimum_version = "0.4.1")
  d <- synth_single(n_t = 150, seed = 812)
  vars <- c("A", "B", "C")
  mask_beta <- matrix(c(0, 1, 1, 1, 0, 1, 1, 1, 0), 3, 3, byrow = TRUE)
  cases <- list(
    gamma_zero = list(local = list(gamma = 0), ref = list(gamma = 0)),
    unpenalized_ar = list(
      local = list(penalize_diagonal = FALSE),
      ref = list(penalize.diagonal = FALSE)
    ),
    fixed_kappa = list(
      local = list(lambda_kappa = 0.1), ref = list(lambda_kappa = 0.1)
    ),
    beta_mask = list(
      local = list(regularize_mat_beta = mask_beta),
      ref = list(regularize_mat_beta = mask_beta)
    ),
    penalized_likelihood = list(
      local = list(likelihood = "penalized"),
      ref = list(likelihood = "penalized")
    ),
    both_fixed = list(
      local = list(lambda_beta = 0.08, lambda_kappa = 0.08),
      ref = list(lambda_beta = 0.08, lambda_kappa = 0.08)
    )
  )

  for (case in cases) {
    local <- do.call(fit_graphical_var, c(list(
      data = d, vars = vars, id = "id", day = "day", beep = "beep",
      n_lambda = 15, verbose = FALSE
    ), case$local))
    ref <- suppressWarnings(do.call(graphicalVAR::graphicalVAR, c(list(
      data = d[, c(vars, "id", "day", "beep")], vars = vars,
      idvar = "id", dayvar = "day", beepvar = "beep",
      nLambda = 15, verbose = FALSE
    ), case$ref)))
    expect_equal(local$beta, ref$beta, tolerance = 1e-6, ignore_attr = TRUE)
    expect_equal(local$kappa, ref$kappa, tolerance = 1e-6, ignore_attr = TRUE)
    expect_true(is.finite(local$lambda_beta) && local$lambda_beta >= 0)
    expect_true(is.finite(local$lambda_kappa) && local$lambda_kappa >= 0)
  }
})

test_that("native fixed mlVAR matches upstream across preparation controls", {
  skip_unless_equivalence()
  skip_if_not_installed("mlVAR", minimum_version = "0.7.3")
  d <- synth_panel(n_id = 12, days = 3, beeps = 12, seed = 813)
  vars <- c("A", "B", "C")
  true_means <- stats::aggregate(d[vars], list(id = d$id), mean)
  cases <- list(
    both_scaled = list(scale = TRUE, scaleWithin = TRUE),
    multi_lag = list(lags = c(1L, 2L)),
    aligned_lag = list(lags = 1L, compare_to_lags = c(1L, 2L)),
    known_means = list(true_means = true_means),
    position_detrend = list(detrend = "position")
  )

  for (args in cases) {
    local <- suppressWarnings(do.call(fit_mlvar, c(list(
      data = d, vars = vars, id = "id", day = "day", beep = "beep"
    ), args)))
    ref <- suppressWarnings(do.call(fit_mlvar, c(list(
      data = d, vars = vars, id = "id", day = "day", beep = "beep",
      engine = "reference"
    ), args)))
    local_temporal <- grep("^temporal", names(local), value = TRUE)
    ref_temporal <- grep("^temporal", names(ref), value = TRUE)
    expect_identical(length(local_temporal), length(ref_temporal))
    for (k in seq_along(local_temporal)) {
      expect_equal(local[[local_temporal[k]]]$weights,
                   ref[[ref_temporal[k]]]$weights,
                   tolerance = 1e-8, ignore_attr = TRUE)
    }
    expect_equal(local$contemporaneous$weights,
                 ref$contemporaneous$weights,
                 tolerance = 1e-8, ignore_attr = TRUE)
    expect_equal(local$between$weights, ref$between$weights,
                 tolerance = 1e-8, ignore_attr = TRUE)
    expect_equal(attr(local, "n_obs"), attr(ref, "n_obs"))
    expect_identical(equivalence(local)$status, "validated")
  }
})

test_that("native unique mlVAR matches every upstream contemporaneous mode", {
  skip_unless_equivalence()
  skip_if_not_installed("mlVAR", minimum_version = "0.7.3")
  d <- synth_panel(n_id = 12, days = 3, beeps = 12, seed = 816)
  vars <- c("A", "B", "C")

  for (mode in c("fixed", "unique", "correlated", "orthogonal")) {
    args <- list(
      data = d, vars = vars, id = "id", day = "day", beep = "beep",
      estimator = "lm", temporal = "unique", contemporaneous = mode
    )
    local <- suppressWarnings(do.call(fit_mlvar, args))
    ref <- suppressWarnings(do.call(fit_mlvar, c(args, list(engine = "reference"))))
    expect_equal(local$temporal$weights, ref$temporal$weights,
                 tolerance = 1e-8, ignore_attr = TRUE)
    expect_equal(local$contemporaneous$weights,
                 ref$contemporaneous$weights,
                 tolerance = 1e-8, ignore_attr = TRUE)
    expect_equal(local$between$weights, ref$between$weights,
                 tolerance = 1e-8, ignore_attr = TRUE)
    expect_identical(equivalence(local)$status, "validated")
  }
})

.gimme10_reference <- function(data, ...) {
  fun <- get("gimme", envir = asNamespace("gimme"))
  capture_line <- paste(deparse(body(fun)[[2L]]), collapse = " ")
  if (grepl("as.list", capture_line, fixed = TRUE) &&
      grepl("sys.frame", capture_line, fixed = TRUE)) {
    # gimme 10.0's argument-capture expression recursively evaluates promises
    # under R 4.6. Replacing only that bookkeeping assignment leaves setup,
    # search, pruning, fitting, and extraction byte-for-byte upstream code.
    body(fun)[[2L]] <- quote(
      arguments <- as.list(match.call(expand.dots = TRUE))
    )
  }
  invisible(utils::capture.output(
    result <- suppressMessages(fun(data = data, plot = FALSE, ...))
  ))
  result
}

.canonical_gimme_syntax <- function(x) {
  sort(vapply(trimws(x), function(term) {
    sides <- strsplit(term, "~~", fixed = TRUE)[[1L]]
    if (length(sides) == 2L) paste(sort(sides), collapse = "~~") else term
  }, character(1), USE.NAMES = FALSE))
}

.expect_gimme10_equal <- function(local, ref) {
  expect_equal(local$path_counts, ref$path_counts, tolerance = 0,
               ignore_attr = TRUE)
  expect_equal(local$contemp_cov, ref$cov_counts, tolerance = 0,
               ignore_attr = TRUE)
  expect_true(all(mapply(
    function(x, y) identical(.canonical_gimme_syntax(x),
                              .canonical_gimme_syntax(y)),
    unname(local$syntax), unname(ref$syntax)
  )))
  expect_equal(unname(local$coefs), unname(ref$path_est_mats), tolerance = 0)
  expect_equal(unname(local$psi), unname(ref$psi), tolerance = 0)

  # gimme rounds its returned fit table to four decimals. idiographic retains
  # lavaan's full precision, so half a unit in the fourth decimal is the exact
  # comparison bound implied by that public upstream representation.
  fit_cols <- intersect(
    c("chisq", "df", "pvalue", "rmsea", "srmr", "nnfi", "cfi",
      "bic", "aic", "logl"),
    intersect(names(local$fit), names(ref$fit))
  )
  expect_equal(as.matrix(local$fit[fit_cols]), as.matrix(ref$fit[fit_cols]),
               tolerance = 5e-5, ignore_attr = TRUE)
  expect_identical(as.character(local$fit$status),
                   as.character(ref$fit$status))
}

test_that("GIMME standard, hybrid, and VAR searches match gimme 10.0", {
  skip_unless_equivalence()
  skip_if_not_installed("gimme", minimum_version = "10.0")
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 4, days = 1, beeps = 40,
                   vars = c("A", "B"), seed = 817)
  series <- lapply(split(d, d$id), function(z) {
    as.matrix(z[, c("A", "B"), drop = FALSE])
  })
  modes <- list(standard = list(), hybrid = list(hybrid = TRUE),
                VAR = list(VAR = TRUE))

  for (mode in modes) {
    ref <- do.call(.gimme10_reference, c(list(data = series), mode))
    local <- suppressMessages(do.call(fit_gimme, c(list(
      data = d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
      seed = 1
    ), mode)))
    .expect_gimme10_equal(local, ref)
    expect_identical(equivalence(local)$status, "validated")
    expect_equal(equivalence(local)$tolerance, c(0, 5e-5))
  }
})

test_that("GIMME 10.0 correction and stopping controls match upstream", {
  skip_unless_equivalence()
  skip_if_not_installed("gimme", minimum_version = "10.0")
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 4, days = 1, beeps = 40,
                   vars = c("A", "B"), seed = 818)
  series <- lapply(split(d, d$id), function(z) {
    as.matrix(z[, c("A", "B"), drop = FALSE])
  })
  cases <- list(
    alpha = list(alpha = .1),
    fdr = list(group_correct = "fdr", indiv_correct = "fdr"),
    bonferroni_paths = list(group_correct = "Bonferroni Paths"),
    numeric_group_alpha = list(group_correct = .01),
    standard = list(stop_crit = "standard"),
    significance = list(stop_crit = "significance"),
    standardized = list(standardize = TRUE),
    group_cutoff = list(groupcutoff = .5),
    fit_cutoffs = list(rmsea_cutoff = .1, srmr_cutoff = .1,
                       nnfi_cutoff = .9, cfi_cutoff = .9, n_excellent = 3L),
    forced_path = list(paths = "B~Alag")
  )

  for (case in cases) {
    ref <- do.call(.gimme10_reference, c(list(data = series), case))
    local <- suppressMessages(do.call(fit_gimme, c(list(
      data = d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
      seed = 1
    ), case)))
    .expect_gimme10_equal(local, ref)
    expect_identical(equivalence(local)$status, "validated")
  }
})

test_that("GIMME exogenous-variable structure matches gimme 10.0", {
  skip_unless_equivalence()
  skip_if_not_installed("gimme", minimum_version = "10.0")
  skip_if_not_installed("lavaan")
  vars <- c("A", "B", "C")
  d <- synth_panel(n_id = 5, days = 1, beeps = 50, vars = vars, seed = 829)
  series <- lapply(split(d, d$id), function(z) {
    as.matrix(z[, vars, drop = FALSE])
  })

  ref <- .gimme10_reference(series, exogenous = "C")
  local <- suppressMessages(fit_gimme(
    d, vars = vars, id = "id", day = "day", beep = "beep",
    exogenous = "C", seed = 1
  ))

  .expect_gimme10_equal(local, ref)
  expect_identical(dim(local$coefs[[1L]]), c(2L, 5L))
  expect_identical(dim(local$temporal), c(3L, 3L))
  expect_identical(dim(local$contemporaneous), c(3L, 3L))
  expect_false("Clag" %in% colnames(local$path_counts))
  tidy_coefs <- coefs(local)
  expect_s3_class(tidy_coefs, "data.frame")
  expect_false(any(tidy_coefs$network == "temporal" &
                     tidy_coefs$from == "C"))
  plotted <- as_netobject(local)
  expect_s3_class(plotted, "netobject_group")
  expect_s3_class(plotted$temporal, "cograph_network")
  expect_identical(equivalence(local)$status, "validated")
})

test_that("GIMME multivariate interactions and uneven panels match gimme 10.0", {
  skip_unless_equivalence()
  skip_if_not_installed("gimme", minimum_version = "10.0")
  skip_if_not_installed("lavaan")
  vars <- c("A", "B", "C")
  base <- synth_panel(n_id = 5, days = 1, beeps = 50,
                      vars = vars, seed = 830)
  keep <- c(50L, 43L, 47L, 39L, 45L)
  uneven <- base[base$beep <= keep[base$id], , drop = FALSE]
  cases <- list(
    uneven_standard = list(data = uneven, args = list()),
    corrected_hybrid = list(
      data = base,
      args = list(
        hybrid = TRUE, group_correct = "fdr", indiv_correct = "fdr",
        alpha = .1, stop_crit = "significance", standardize = TRUE,
        groupcutoff = .6
      )
    )
  )

  for (case in cases) {
    series <- lapply(split(case$data, case$data$id), function(z) {
      as.matrix(z[, vars, drop = FALSE])
    })
    ref <- do.call(.gimme10_reference,
                   c(list(data = series), case$args))
    local <- suppressMessages(do.call(fit_gimme, c(list(
      data = case$data, vars = vars, id = "id", day = "day", beep = "beep",
      seed = 1
    ), case$args)))
    .expect_gimme10_equal(local, ref)
    expect_identical(equivalence(local)$status, "validated")
  }
})

# ---- moved from test-fixtures-equivalence.R (equivalence lane only) ----

test_that("fixture-backed fit_mlvar is cell-equivalent to mlVAR", {
  skip_unless_equivalence()
  skip_if_not_installed("mlVAR")
  source(testthat::test_path("fixtures", "equivalence-panel.R"), local = TRUE)
  d <- .fixture_equivalence_panel()
  vars <- c("A", "B", "C")

  fit <- suppressWarnings(
    fit_mlvar(d, vars = vars, id = "id", day = "day", beep = "beep")
  )
  ref <- suppressWarnings(mlVAR::mlVAR(
    d, vars = vars, idvar = "id", dayvar = "day", beepvar = "beep",
    estimator = "lmer", temporal = "fixed", contemporaneous = "fixed",
    scale = FALSE, verbose = FALSE
  ))

  expect_matrix_cells_equal(fit$temporal$weights, ref$results$Beta$mean[, , 1],
                            tolerance = 1e-10, label = "temporal")
  expect_vector_cells_equal(upper_triangle_values(fit$contemporaneous$weights),
                            upper_triangle_values(ref$results$Theta$pcor$mean),
                            tolerance = 1e-10,
                            label = "contemporaneous_upper")
  expect_vector_cells_equal(upper_triangle_values(fit$between$weights),
                            upper_triangle_values(ref$results$Omega_mu$pcor$mean),
                            tolerance = 1e-10, label = "between_upper")
})

test_that("fixture-backed graphical_var is cell-equivalent to graphicalVAR", {
  skip_unless_equivalence()
  skip_if_not_installed("graphicalVAR")
  source(testthat::test_path("fixtures", "equivalence-panel.R"), local = TRUE)
  d <- .fixture_equivalence_series()
  vars <- c("A", "B", "C")

  fit <- fit_graphical_var(d, vars = vars, id = "id", day = "day", beep = "beep",
                       n_lambda = 12, gamma = 0.5)
  ref <- suppressWarnings(graphicalVAR::graphicalVAR(
    d[, c(vars, "id", "day", "beep")], vars = vars,
    idvar = "id", dayvar = "day", beepvar = "beep",
    nLambda = 12, gamma = 0.5, verbose = FALSE
  ))

  expect_matrix_cells_equal(fit$beta, ref$beta, tolerance = 1e-4,
                            label = "beta")
  expect_matrix_cells_equal(fit$kappa, ref$kappa, tolerance = 1e-4,
                            label = "kappa")
})

# ---- moved from test-mlvar.R (equivalence lane only) ----

test_that("matches mlVAR to machine precision on well-conditioned data", {
  skip_unless_equivalence()
  skip_if_not_installed("mlVAR")
  d <- synth_panel(n_id = 20, days = 6, beeps = 10, seed = 21)
  vars <- c("A", "B", "C")
  fit <- suppressWarnings(
    fit_mlvar(d, vars = vars, id = "id", day = "day", beep = "beep")
  )
  ref <- suppressWarnings(mlVAR::mlVAR(
    d, vars = vars, idvar = "id", dayvar = "day", beepvar = "beep",
    estimator = "lmer", temporal = "fixed", contemporaneous = "fixed",
    scale = FALSE, verbose = FALSE
  ))
  # Temporal fixed effects: exact ([response, predictor] orientation).
  expect_equal(fit$temporal$weights, ref$results$Beta$mean[, , 1],
               tolerance = 1e-8, ignore_attr = TRUE)
  # Off-diagonal contemporaneous / between pcor (diagonals differ by convention).
  co <- fit$contemporaneous$weights
  rc <- ref$results$Theta$pcor$mean
  expect_equal(co[upper.tri(co)], rc[upper.tri(rc)], tolerance = 1e-8)
  bt <- fit$between$weights
  rb <- ref$results$Omega_mu$pcor$mean
  expect_equal(bt[upper.tri(bt)], rb[upper.tri(rb)], tolerance = 1e-8)
})

test_that("AR = TRUE gives a diagonal temporal matrix matching mlVAR", {
  skip_unless_equivalence()
  skip_if_not_installed("mlVAR")
  d <- synth_panel(n_id = 18, days = 5, beeps = 11, seed = 31)
  vars <- c("A", "B", "C")
  fit <- suppressWarnings(fit_mlvar(d, vars = vars, id = "id", day = "day",
                                      beep = "beep", AR = TRUE))
  B <- fit$temporal$weights
  expect_true(all(B[row(B) != col(B)] == 0))      # off-diagonal exactly 0
  ref <- suppressWarnings(mlVAR::mlVAR(
    d, vars = vars, idvar = "id", dayvar = "day", beepvar = "beep",
    estimator = "lmer", temporal = "fixed", contemporaneous = "fixed",
    AR = TRUE, scale = FALSE, verbose = FALSE))
  expect_equal(B, ref$results$Beta$mean[, , 1], tolerance = 1e-8,
               ignore_attr = TRUE)
  # AR off-diagonal coefs are coherent: beta 0, significant FALSE (not NA).
  co <- coefs(fit)
  off <- co[co$outcome != co$predictor, , drop = FALSE]
  expect_true(all(off$beta == 0))
  expect_false(any(is.na(off$significant)))
  expect_true(all(!off$significant))
})

test_that("reference engine converts upstream output without changing layers", {
  skip_unless_equivalence()
  skip_if_not_installed("mlVAR")
  d <- synth_panel(n_id = 10, days = 3, beeps = 10, seed = 72)
  fit <- suppressWarnings(fit_mlvar(
    d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
    engine = "reference", verbose = FALSE
  ))
  expect_s3_class(fit, "net_mlvar_reference")
  expect_named(fit, c("temporal", "contemporaneous", "between"))
  expect_equal(nrow(coefs(fit)), 9L)
  expect_identical(equivalence(fit)$status, "delegated")
})

# ---- moved from test-graphical-var.R (equivalence lane only) ----

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

# ---- moved from test-package-closure.R (equivalence lane only) ----

test_that("native lmer mlVAR matches every supported random-effect structure", {
  skip_unless_equivalence()
  skip_if_not_installed("mlVAR", minimum_version = "0.7.3")
  d <- synth_panel(n_id = 14, days = 2, beeps = 12,
                   vars = c("A", "B", "C"), seed = 905)
  structures <- expand.grid(
    temporal = c("fixed", "correlated", "orthogonal"),
    contemporaneous = c("fixed", "unique", "correlated", "orthogonal"),
    stringsAsFactors = FALSE
  )

  for (i in seq_len(nrow(structures))) {
    args <- list(
      data = d, vars = c("A", "B", "C"), id = "id", day = "day",
      beep = "beep", scale = FALSE,
      temporal = structures$temporal[i],
      contemporaneous = structures$contemporaneous[i]
    )
    local <- suppressWarnings(do.call(fit_mlvar, args))
    ref <- suppressWarnings(do.call(fit_mlvar,
                                    c(args, list(engine = "reference"))))
    for (network in c("temporal", "contemporaneous", "between")) {
      expect_lte(max(abs(local[[network]]$weights -
                         ref[[network]]$weights), na.rm = TRUE), 1e-8)
    }
    expect_identical(equivalence(local)$status, "validated")
  }
})

test_that("per-subject graphical VAR equals direct upstream subject fits", {
  skip_unless_equivalence()
  skip_if_not_installed("graphicalVAR", minimum_version = "0.4.1")
  d <- synth_panel(n_id = 3, days = 1, beeps = 55,
                   vars = c("A", "B", "C"), seed = 904)
  local <- fit_graphical_var_each(
    d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
    n_lambda = 8, verbose = FALSE
  )

  expect_identical(length(local), 3L)
  for (sid in names(local)) {
    one <- d[d$id == as.integer(sid), , drop = FALSE]
    ref <- suppressWarnings(graphicalVAR::graphicalVAR(
      one, vars = c("A", "B", "C"), idvar = "id", dayvar = "day",
      beepvar = "beep", nLambda = 8, verbose = FALSE
    ))
    expect_lte(max(abs(local[[sid]]$beta - ref$beta)), 1e-6)
    expect_lte(max(abs(local[[sid]]$kappa - ref$kappa)), 1e-6)
  }
  expect_identical(equivalence(local)$status, "validated")
})

test_that("graphical VAR closes multi-ID, missingness, and grid argument cells", {
  skip_unless_equivalence()
  skip_if_not_installed("graphicalVAR", minimum_version = "0.4.1")
  d <- synth_panel(n_id = 8, days = 2, beeps = 12,
                   vars = c("A", "B", "C"), seed = 906)
  vars <- c("A", "B", "C")
  cases <- list(
    center = list(local = list(center_within = FALSE),
                  ref = list(centerWithin = FALSE)),
    lambda_minima = list(
      local = list(lambda_min_kappa = .2, lambda_min_beta = .1),
      ref = list(lambda_min_kappa = .2, lambda_min_beta = .1)
    )
  )
  for (case in cases) {
    local <- do.call(fit_graphical_var, c(list(
      data = d, vars = vars, id = "id", day = "day", beep = "beep",
      n_lambda = 10
    ), case$local))
    ref <- suppressWarnings(do.call(graphicalVAR::graphicalVAR, c(list(
      data = d[, c(vars, "id", "day", "beep")], vars = vars,
      idvar = "id", dayvar = "day", beepvar = "beep",
      nLambda = 10, verbose = FALSE
    ), case$ref)))
    expect_lte(max(abs(local$beta - ref$beta)), 1e-6)
    expect_lte(max(abs(local$kappa - ref$kappa)), 1e-6)
  }

  with_na <- d
  with_na$A[c(4, 30)] <- NA_real_
  local_na <- fit_graphical_var(
    with_na, vars = vars, id = "id", day = "day", beep = "beep",
    n_lambda = 8, delete_missings = TRUE
  )
  ref_na <- suppressWarnings(graphicalVAR::graphicalVAR(
    with_na[, c(vars, "id", "day", "beep")], vars = vars,
    idvar = "id", dayvar = "day", beepvar = "beep", nLambda = 8,
    deleteMissings = TRUE, verbose = FALSE
  ))
  expect_lte(max(abs(local_na$beta - ref_na$beta)), 1e-6)
  expect_lte(max(abs(local_na$kappa - ref_na$kappa)), 1e-6)

  unequal <- fit_graphical_var(
    d, vars = vars, id = "id", day = "day", beep = "beep",
    n_lambda = c(beta = 4, kappa = 3),
    lambda_beta = .08, lambda_kappa = .08
  )
  expect_identical(equivalence(unequal)$status, "supported_extension")
})

# ---- moved from test-gimme.R (equivalence lane only) ----

test_that("fit_gimme covers the full gimme::gimme() argument surface", {
  skip_unless_equivalence()
  skip_if_not_installed("gimme")
  missing <- setdiff(names(formals(gimme::gimme)), names(formals(fit_gimme)))
  expect_length(missing, 0L)
})

# ---- moved from test-glasso.R (equivalence lane only) ----

test_that(".glasso_fit matches glasso when available", {
  skip_unless_equivalence()
  skip_if_not_installed("glasso")
  set.seed(2)
  X <- matrix(stats::rnorm(300 * 4), ncol = 4)
  S <- stats::cov(X)
  rho <- 0.15
  ours <- idiographic:::.glasso_fit(S, rho)$wi
  ref  <- glasso::glasso(S, rho = rho, penalize.diagonal = FALSE)$wi
  expect_equal(ours, ref, tolerance = 1e-4, ignore_attr = TRUE)
})
