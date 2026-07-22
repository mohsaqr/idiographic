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
