# Regression tests for two code-review findings:
#  1. A zero-edge GIMME fit must return (not error) during estimation.
#  2. Whole-object plot() must render the temporal network in plotting
#     orientation (predictor -> outcome), not the raw [outcome, predictor] matrix.

on_null_device <- function(code) {
  grDevices::pdf(NULL); on.exit(grDevices::dev.off(), add = TRUE); force(code)
}

# ---- Finding 1: zero-edge GIMME -------------------------------------------
zero_gimme <- function() {
  vars <- c("A", "B", "C")
  list(labels = vars, n_subjects = 5L,
       path_counts = matrix(0, 3, 6,
         dimnames = list(vars, c(paste0(vars, "lag"), vars))),
       temporal_avg = matrix(0, 3, 3, dimnames = list(vars, vars)),
       contemporaneous_avg = matrix(0, 3, 3, dimnames = list(vars, vars)),
       contemp_is_cov = FALSE, group_paths = character(0),
       config = list(fixed_paths = character(0)))
}

test_that(".gimme_mixed_edges returns an empty edge list instead of erroring", {
  edf <- .gimme_mixed_edges(zero_gimme())
  expect_s3_class(edf, "data.frame")
  expect_equal(nrow(edf), 0L)
  expect_true(all(c("from", "to", "weight", "style", "kind", "path") %in%
                    names(edf)))
})

test_that(".gimme_cograph_network builds a zero-edge net_gimme (build returns)", {
  net <- .gimme_cograph_network(zero_gimme())
  expect_s3_class(net, "net_gimme")
  expect_equal(nrow(net$edges), 0L)
  expect_equal(length(net$labels), 3L)
})

test_that("plot_gimme on a zero-edge fit draws nodes only (no cograph error)", {
  skip_if_not_installed("cograph")
  net <- .gimme_cograph_network(zero_gimme())
  on_null_device(
    expect_message(expect_invisible(plot_gimme(net)), "no estimated paths")
  )
})

# ---- Finding 2: whole-object plot temporal orientation --------------------
small_mlvar <- function() {
  set.seed(1)
  rows <- lapply(1:8, function(i) {
    m <- as.data.frame(matrix(rnorm(80 * 2), ncol = 2)); names(m) <- c("A", "B")
    m$id <- i; m$beep <- seq_len(80); m
  })
  suppressWarnings(
    fit_mlvar(do.call(rbind, rows), vars = c("A", "B"), id = "id", beep = "beep")
  )
}

test_that("as_netobject transposes the temporal network (orientation the plot uses)", {
  fit <- small_mlvar()
  # stored weights keep mlVAR's [outcome, predictor] layout (equivalence);
  # the plotting netobject is its transpose (predictor -> outcome).
  expect_equal(as_netobject(fit)$temporal$weights, t(fit$temporal$weights))
})

test_that("whole-object plot(net_mlvar) and single layers render without error", {
  skip_if_not_installed("cograph")
  fit <- small_mlvar()
  on_null_device({
    expect_invisible(plot(fit))                       # whole result
    expect_invisible(plot(fit, layer = "temporal"))   # single layer
    expect_invisible(plot(fit, layer = "between"))
    expect_error(plot(fit, layer = "nope"), "Unknown layer")
  })
})

test_that("plot.var_bayes_result is dispatched (whole result and single layer)", {
  skip_if_not_installed("cograph"); skip_if_not_installed("corpcor")
  set.seed(1); y <- matrix(0, 150, 2)
  for (t in 2:150) y[t, ] <- c(0.4, 0.3) * y[t - 1, ] + rnorm(2)
  fit <- fit_var_bayes(data.frame(A = y[, 1], B = y[, 2]),
                         vars = c("A", "B"), n_iter = 600, seed = 1)
  expect_s3_class(fit, "var_bayes_result")
  on_null_device({
    expect_invisible(plot(fit))                       # was broken: no method
    expect_invisible(plot(fit, layer = "temporal"))
  })
})

# ---- Sample-size guards for the improper-prior covariance draws -----------
mk_panel <- function(nid, p = 2) {
  do.call(rbind, lapply(seq_len(nid), function(i) {
    set.seed(i); y <- matrix(0, 30, p)
    for (t in 2:30) y[t, ] <- 0.3 * y[t - 1, ] + rnorm(p)
    d <- data.frame(id = i, beep = seq_len(30))
    for (j in seq_len(p)) d[[paste0("V", j)]] <- y[, j]
    d
  }))
}

test_that("fixed sampler errors below 2p+1 subjects (between covariance)", {
  skip_if_not_installed("corpcor")
  vars <- c("V1", "V2")                                # p = 2 -> need >= 5
  expect_error(
    fit_mlvar_bayes(mk_panel(4), vars = vars, id = "id", beep = "beep",
                      n_iter = 200),
    "at least 5")
  expect_silent_fit <- fit_mlvar_bayes(mk_panel(6), vars = vars, id = "id",
                                         beep = "beep", n_iter = 300, seed = 1)
  expect_true(all(is.finite(attr(expect_silent_fit, "matrices")$B)))
})

test_that("fit_var_bayes errors below 2p+1 lag pairs", {
  skip_if_not_installed("corpcor")
  d <- data.frame(A = rnorm(4), B = rnorm(4))          # ~3 lag pairs < 5
  expect_error(
    fit_var_bayes(d, vars = c("A", "B"), n_iter = 200),
    "at least 5|Too few")
})
