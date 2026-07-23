test_that("fit_gimme exposes the current GIMME 10.0 search controls", {
  skip_on_cran()
  f <- formals(fit_gimme)
  upstream_surface <- c(
    "data", "out", "sep", "header", "ar", "plot", "subgroup",
    "sub_feature", "sub_method", "sub_sim_thresh", "confirm_subgroup",
    "paths", "exogenous", "outcome", "conv_vars", "conv_length",
    "conv_interval", "mult_vars", "mean_center_mult", "standardize",
    "groupcutoff", "subcutoff", "diagnos", "ms_allow", "ms_tol",
    "lv_model", "lv_estimator", "lv_scores", "lv_miiv_scaling",
    "lv_final_estimator", "lasso_model_crit", "hybrid", "VAR",
    "dir_prop_cutoff", "ordered", "group_correct", "indiv_correct",
    "alpha", "stop_crit", "rmsea_cutoff", "srmr_cutoff", "nnfi_cutoff",
    "cfi_cutoff", "n_excellent"
  )
  expect_length(setdiff(upstream_surface, names(f)), 0L)
  expect_true(all(c("group_correct", "indiv_correct", "alpha", "stop_crit") %in%
                    names(f)))
  expect_identical(f$group_correct, "Bonferroni Group")
  expect_identical(f$indiv_correct, "Bonferroni")
  expect_identical(f$alpha, 0.05)
  expect_identical(f$stop_crit, "model fit")
})

test_that("group correction names include current and deprecated spellings", {
  skip_on_cran()
  normalize <- idiographic:::.gimme_normalize_group_correct

  expect_identical(normalize("Bonferroni Group"), "Bonferroni Group")
  expect_identical(normalize("Bonferroni Paths"), "Bonferroni Paths")
  expect_identical(normalize("fdr"), "fdr")
  expect_identical(normalize(0.10), 0.10)
  expect_warning(
    expect_identical(normalize("Bonferoni Group"), "Bonferroni Group"),
    "deprecated"
  )

  expect_error(normalize("none"), "Bonferroni Group")
  expect_error(normalize(0), "between 0 and 1")
  expect_error(normalize(1), "between 0 and 1")
  expect_error(normalize(c(0.01, 0.02)), "single finite")
})

test_that("group correction modes produce their documented thresholds", {
  skip_on_cran()
  thresholds <- idiographic:::.gimme_group_thresholds

  by_group <- thresholds("Bonferroni Group", alpha = 0.05,
                         n_subj = 10L, n_paths = 20L)
  expect_equal(by_group$test_alpha, 0.005)
  expect_equal(by_group$chisq, stats::qchisq(0.995, 1))
  expect_equal(by_group$z, abs(stats::qnorm(0.0025)))
  expect_identical(by_group$correction, "Bonferroni")

  by_path <- thresholds("Bonferroni Paths", alpha = 0.05,
                        n_subj = 10L, n_paths = 20L)
  expect_equal(by_path$test_alpha, 0.0025)
  expect_equal(by_path$chisq, stats::qchisq(0.9975, 1))

  direct <- thresholds(0.10, alpha = 0.05, n_subj = 10L, n_paths = 20L)
  expect_equal(direct$test_alpha, 0.10)
  expect_equal(direct$chisq, stats::qchisq(0.90, 1))
  expect_identical(direct$correction, "fixed")

  fdr <- thresholds("fdr", alpha = 0.05, n_subj = 10L, n_paths = 20L)
  expect_equal(fdr$test_alpha, 0.05)
  expect_identical(fdr$correction, "fdr")
})

test_that("individual Bonferroni and FDR controls affect entry and pruning", {
  skip_on_cran()
  thresholds <- idiographic:::.gimme_individual_thresholds
  bonf <- thresholds("Bonferroni", alpha = 0.05, n_paths = 10L)
  fdr <- thresholds("fdr", alpha = 0.05, n_paths = 10L)

  expect_equal(bonf$test_alpha, 0.005)
  expect_equal(bonf$chisq, stats::qchisq(0.995, 1))
  expect_equal(bonf$z, abs(stats::qnorm(0.005)))
  expect_equal(fdr$test_alpha, 0.05)
  expect_equal(fdr$chisq, stats::qchisq(0.95, 1))
  expect_equal(fdr$z, abs(stats::qnorm(0.05)))

  p <- c(0.01, 0.04, 0.20)
  mi <- stats::qchisq(1 - p, df = 1)
  expect_identical(
    idiographic:::.gimme_significant_mi(
      mi, chisq_cutoff = fdr$chisq, correction = "fdr", alpha = 0.05
    ),
    c(TRUE, FALSE, FALSE)
  )
})

test_that("group FDR is applied across pooled person-by-path tests", {
  skip_on_cran()
  make_mi <- function(p1, p2) {
    data.frame(
      lhs = c("A", "B"), op = "~", rhs = c("B", "A"),
      mi = stats::qchisq(1 - c(p1, p2), df = 1)
    )
  }
  mi_list <- list(
    make_mi(0.001, 0.03),
    make_mi(0.010, 0.40),
    make_mi(0.200, 0.50)
  )

  selected <- idiographic:::.gimme_select_path(
    mi_list = mi_list,
    elig_paths = c("A~B", "B~A"),
    prop_cutoff = 0.50,
    n_subj = 3L,
    chisq_cutoff = stats::qchisq(0.95, 1),
    hybrid = FALSE,
    correction = "fdr",
    alpha = 0.05
  )
  expect_identical(selected, "A~B")
})

test_that("individual stopping modes separate fit and significance", {
  skip_on_cran()
  choose <- idiographic:::.gimme_choose_individual_path
  cutoff <- stats::qchisq(0.95, df = 1)
  weak <- data.frame(
    param = c("A~B", "B~A"),
    mi = stats::qchisq(1 - c(0.20, 0.10), df = 1)
  )
  strong <- data.frame(
    param = c("A~B", "B~A"),
    mi = stats::qchisq(1 - c(0.20, 0.01), df = 1)
  )

  # No adequate fit: model-fit mode adds the largest MI even when weak;
  # significance-based modes stop when no significant candidate remains.
  expect_identical(choose(weak, FALSE, cutoff, "model fit",
                          "Bonferroni", 0.05), "B~A")
  expect_true(is.na(choose(weak, FALSE, cutoff, "standard",
                           "Bonferroni", 0.05)))
  expect_true(is.na(choose(weak, FALSE, cutoff, "significance",
                           "Bonferroni", 0.05)))

  # Adequate fit stops standard/model-fit searches, but significance mode
  # deliberately continues while a significant candidate remains.
  expect_true(is.na(choose(strong, TRUE, cutoff, "standard",
                           "Bonferroni", 0.05)))
  expect_true(is.na(choose(strong, TRUE, cutoff, "model fit",
                           "Bonferroni", 0.05)))
  expect_identical(choose(strong, TRUE, cutoff, "significance",
                          "Bonferroni", 0.05), "B~A")
})

test_that("new controls are validated at the public interface", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 3, days = 2, beeps = 6, vars = c("A", "B"), seed = 3)

  expect_error(fit_gimme(d, c("A", "B"), "id", alpha = 0), "alpha")
  expect_error(fit_gimme(d, c("A", "B"), "id", alpha = NA_real_), "alpha")
  expect_error(fit_gimme(d, c("A", "B"), "id", indiv_correct = "none"),
               "arg")
  expect_error(fit_gimme(d, c("A", "B"), "id", stop_crit = "none"),
               "arg")
  expect_error(fit_gimme(d, c("A", "B"), "id", group_correct = "none"),
               "Bonferroni Group")
  expect_error(fit_gimme(d, c("A", "B"), "id", hybrid = TRUE, ar = FALSE),
               "ar.*TRUE")
})

test_that("inapplicable subgroup and file-I/O controls are not silent", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 3, days = 2, beeps = 6, vars = c("A", "B"), seed = 3)
  seen <- character()
  gm <- withCallingHandlers(
    suppressMessages(fit_gimme(
      d, c("A", "B"), "id", day = "day", beep = "beep",
      subcutoff = 0.60, out = tempdir(), seed = 1
    )),
    warning = function(w) {
      seen <<- c(seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  expect_s3_class(gm, "net_gimme")
  expect_true(any(grepl("subcutoff", seen, fixed = TRUE)))
  expect_true(any(grepl("file-I/O", seen, fixed = TRUE)))
})

test_that("new controls are recorded by a complete fit", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 3, days = 2, beeps = 8, vars = c("A", "B"), seed = 4)
  gm <- fit_gimme(
    d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    group_correct = 0.10, indiv_correct = "fdr", alpha = 0.10,
    stop_crit = "significance", seed = 1
  )

  expect_identical(gm$config$group_correct, 0.10)
  expect_identical(gm$config$indiv_correct, "fdr")
  expect_identical(gm$config$alpha, 0.10)
  expect_identical(gm$config$stop_crit, "significance")
  expect_equal(gm$config$group_chisq_cutoff, stats::qchisq(0.90, 1))
  expect_equal(gm$config$individual_chisq_cutoff, stats::qchisq(0.90, 1))
})
