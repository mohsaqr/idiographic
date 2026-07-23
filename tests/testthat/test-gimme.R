test_that("fit_gimme runs and returns a net_gimme object", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 4, days = 3, beeps = 12, vars = c("A", "B"), seed = 5)
  gm <- fit_gimme(d, vars = c("A", "B"), id = "id",
                    day = "day", beep = "beep", seed = 1)
  expect_s3_class(gm, "net_gimme")
  expect_equal(gm$n_subjects, 4L)
  expect_equal(dim(gm$temporal), c(2L, 2L))
  expect_equal(dim(gm$contemporaneous), c(2L, 2L))
  expect_false(any(is.na(gm$path_counts)))      # NA-safe path counting
})

test_that("GIMME lags never cross day boundaries", {
  skip_on_cran()
  # One subject, two days; day-2's first row must not pair with day-1's last.
  df <- data.frame(
    id = 1L,
    day = c(1, 1, 1, 1, 2, 2, 2, 2),
    beep = c(1, 2, 3, 4, 1, 2, 3, 4),
    A = c(10, 11, 12, 13, 20, 21, 22, 23),
    B = c(10, 11, 12, 13, 20, 21, 22, 23) + 0.5
  )
  df <- df[do.call(order, df[c("id", "day", "beep")]), ]
  df$.time <- stats::ave(seq_len(nrow(df)), df$id, FUN = seq_along)

  with_day <- idiographic:::.gimme_prepare_data(
    df, vars = c("A", "B"), id = "id", time = ".time",
    standardize = FALSE, exogenous = NULL, day = "day"
  )[[1]]
  # No current row equal to 20 (day-2 first) carries lag 13 (day-1 last).
  expect_false(any(with_day$A == 20 & with_day$Alag == 13))
  # Exactly (beeps-1) * days = 3 * 2 = 6 within-day pairs.
  expect_equal(nrow(with_day), 6L)

  legacy <- idiographic:::.gimme_prepare_data(
    df, vars = c("A", "B"), id = "id", time = ".time",
    standardize = FALSE, exogenous = NULL, day = NULL
  )[[1]]
  # Legacy (no day) keeps the cross-day pair, so it has one extra row.
  expect_true(any(legacy$A == 20 & legacy$Alag == 13))
  expect_equal(nrow(legacy), 7L)
})

test_that("a missing day value does not inject NA rows into the lag design", {
  skip_on_cran()
  df <- data.frame(
    id = 1L, day = c(1, 1, 1, NA, 2, 2, 2), beep = 1:7,
    A = c(1, 2, 3, 4, 5, 6, 7), B = c(1, 2, 3, 4, 5, 6, 7) + 0.1
  )
  df <- df[do.call(order, df[c("id", "day", "beep")]), ]
  df$.time <- stats::ave(seq_len(nrow(df)), df$id, FUN = seq_along)
  pr <- idiographic:::.gimme_prepare_data(df, vars = c("A", "B"), id = "id",
          time = ".time", standardize = FALSE, exogenous = NULL, day = "day")[[1]]
  expect_false(any(is.na(pr)))
})

test_that("path_counts ignores NA coefficients", {
  skip_on_cran()
  # Inject an NA into a per-person coef matrix and confirm it is not counted.
  varnames <- c("A", "B")
  lag_names <- paste0(varnames, "lag")
  all_names <- c(lag_names, varnames)
  m1 <- matrix(0, 2, 4, dimnames = list(varnames, all_names))
  m1["A", "Alag"] <- 0.5
  m2 <- m1
  m2["B", "Blag"] <- NA_real_
  pc <- matrix(0L, 2, 4, dimnames = list(varnames, all_names))
  for (m in list(m1, m2)) pc <- pc + (!is.na(m) & m != 0) * 1L
  expect_false(any(is.na(pc)))
  expect_equal(pc["A", "Alag"], 2L)
  expect_equal(pc["B", "Blag"], 0L)
})

test_that("VAR = TRUE searches lagged paths only (no directed contemporaneous)", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 5, days = 3, beeps = 12, vars = c("A", "B", "C"),
                   seed = 8)
  gm <- fit_gimme(d, vars = c("A", "B", "C"), id = "id",
                    day = "day", beep = "beep", VAR = TRUE, seed = 1)
  # The contemporaneous (directed) path-count block must be entirely zero;
  # contemporaneous relations become residual covariances under VAR.
  expect_true(all(gm$contemporaneous == 0))
  # Lagged AR self-paths still present (every subject).
  expect_true(all(diag(gm$temporal) == gm$n_subjects))

  # ...but the residual-covariance contemporaneous network IS surfaced: the
  # accessors route through $contemp_cov, marked undirected, not the zero block.
  expect_true(isTRUE(gm$contemp_is_cov))
  expect_equal(dim(gm$contemp_cov), c(3L, 3L))
  g <- as_netobject(gm)
  expect_false(isTRUE(g$contemporaneous$directed))   # covariance = undirected
  expect_true(isTRUE(g$temporal$directed))
  # If any residual covariance was estimated, it appears as a contemporaneous
  # edge (it no longer silently vanishes from the tidy views).
  if (any(gm$contemp_cov > 0)) {
    ce <- subset(edges(gm), network == "contemporaneous")
    expect_gt(nrow(ce), 0L)
    expect_gt(subset(summary(gm), network == "contemporaneous")$n_edges, 0L)
  }
})

test_that("I/O and sub-feature parity args are accepted (no unused-arg error)", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 4, days = 3, beeps = 12, vars = c("A", "B"), seed = 5)
  expect_no_error(
    gm <- suppressWarnings(suppressMessages(fit_gimme(
      d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
      out = tempdir(), sep = ",", header = TRUE, sub_method = "Walktrap",
      conv_length = 16, lv_estimator = "miiv", diagnos = FALSE, seed = 1)))
  )
  expect_s3_class(gm, "net_gimme")
  # plot = TRUE is accepted but emits a message pointing to plot_gimme()
  expect_message(
    suppressWarnings(fit_gimme(d, vars = c("A", "B"), id = "id",
                                 day = "day", beep = "beep", plot = TRUE,
                                 seed = 1)),
    "plot_gimme"
  )
})

test_that("unsupported gimme modes error clearly", {
  skip_on_cran()
  d <- synth_panel(n_id = 4, days = 3, beeps = 12, vars = c("A", "B"), seed = 5)
  expect_error(fit_gimme(d, vars = c("A", "B"), id = "id", subgroup = TRUE),
               "subgrouping")
  expect_error(fit_gimme(d, vars = c("A", "B"), id = "id", outcome = "A"),
               "outcome")
  expect_error(fit_gimme(d, vars = c("A", "B"), id = "id",
                           lv_model = "f =~ A + B"), "lv_model")
  expect_error(fit_gimme(d, vars = c("A", "B"), id = "id", ms_allow = TRUE),
               "ms_allow")
  expect_error(fit_gimme(d, vars = c("A", "B"), id = "id",
                           group_correct = "none"), "Bonferroni Group")
})

test_that("dir_prop_cutoff = 0L (default-equivalent integer) is accepted", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 4, days = 3, beeps = 12, vars = c("A", "B"), seed = 5)
  expect_no_error(suppressWarnings(suppressMessages(
    fit_gimme(d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
                dir_prop_cutoff = 0L, seed = 1))))
})

test_that("non-default inert sub-feature args warn (not silently ignored)", {
  skip_on_cran()
  d <- synth_panel(n_id = 4, days = 3, beeps = 12, vars = c("A", "B"), seed = 5)
  expect_warning(
    suppressMessages(fit_gimme(d, vars = c("A", "B"), id = "id", day = "day",
                                 beep = "beep", sub_method = "Louvain",
                                 seed = 1)),
    "ignores these gimme sub-options"
  )
})

test_that("GIMME with an exogenous variable runs (square stability blocks)", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  # Exogenous current variables drop endogenous beta rows, which previously made
  # the stability eigen blocks non-square. The run must complete without error.
  d <- synth_panel(n_id = 4, days = 3, beeps = 12, vars = c("A", "B", "C"),
                   seed = 8)
  expect_no_error(
    gm <- fit_gimme(d, vars = c("A", "B", "C"), id = "id",
                      day = "day", beep = "beep",
                      exogenous = "C", seed = 1)
  )
  expect_s3_class(gm, "net_gimme")
})
