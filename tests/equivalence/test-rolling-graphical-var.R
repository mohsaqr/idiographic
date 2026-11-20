# fit_rolling_graphical_var(): one regularised graphical VAR per window of consecutive occasions, against
# graphicalVAR::graphicalVAR() 0.4.1 run on the rows of each window with the same grid size and EBIC gamma.
#
# Both sides iterate to their own convergence thresholds (graphicalVAR runs glasso::glasso() at thr = 1e-4,
# idiographic's kernel to 1e-8; FINDINGS.md), so they agree to those thresholds, not to rounding. Here
# graphicalVAR's glasso is run to thr = 1e-12, which test-graphical-var.R shows brings the two to 1e-10; 1e-6 is
# the bound the package's own per-person comparisons used (largest absolute difference).

vars <- c("efficacy", "effort")

#' graphicalVAR's estimate as idiographic's coefficient table, its graphical lasso run to thr = 1e-12
#'
#' graphicalVAR's own code with glasso::glasso() converged; glasso is restored on exit.
gvar_window <- function(rows, vars, ...) {
  imports <- parent.env(asNamespace("graphicalVAR"))
  original <- get("glasso", envir = imports)
  unlockBinding("glasso", imports)
  on.exit({
    assign("glasso", original, envir = imports)
    lockBinding("glasso", imports)
  }, add = TRUE)
  assign("glasso", function(...) original(..., thr = 1e-12, maxit = 1e5), envir = imports)
  fit <- graphicalVAR::graphicalVAR(rows, vars = vars, verbose = FALSE, ...)
  ref_network(temporal = ref_named(fit$beta[, -1L, drop = FALSE], vars)[vars, vars],
              contemporaneous = ref_named(fit$PCC, vars))
}

test_that("each window is graphicalVAR on the rows of the window", {
  skip_without_reference("graphicalVAR")
  learner <- subset(srl, name == "Aisha", select = c(day, efficacy, effort))
  fit <- fit_rolling_graphical_var(learner, vars = vars, beep = "day", window_size = 60, step = 40, n_lambda = 8,
                                   keep_fits = TRUE)
  starts <- seq(1L, nrow(learner) - 59L, by = 40L)
  per_window <- lapply(starts, \(start) gvar_window(learner[seq(start, length.out = 60L), ], vars, beepvar = "day",
                                                    nLambda = 8))
  theirs <- do.call(rbind, Map(\(table, window) cbind(window = window, table), per_window, seq_along(starts)))
  expect_reference(coefs(fit), theirs, reference = "graphicalVAR",
                   covers = c("fit_rolling_graphical_var()", "coefs.rolling_gvar_result()"),
                   quantity = "Aisha, windows of 60 days every 40", tolerance = 1e-6,
                   key = c("window", "network", "from", "to"))
  expect_reference(as.data.frame(fit), theirs, reference = "graphicalVAR",
                   covers = "as.data.frame.rolling_gvar_result()", quantity = "Aisha, the data frame of the windows",
                   tolerance = 1e-6, key = c("window", "network", "from", "to"))
  expect_reference(summary(fit), theirs, reference = "graphicalVAR",
                   covers = "summary.rolling_gvar_result()", quantity = "Aisha, the summary of the windows",
                   tolerance = 1e-6, key = c("window", "network", "from", "to"))
  # API gap: matrices() returns a list of matrices, so the partial contemporaneous correlations are reached by name.
  last <- length(starts)
  partial <- subset(per_window[[last]], network == "contemporaneous")
  pcc <- matrices(fit, fit = last, print = FALSE)[["PCC"]]
  expect_reference(ref_undirected(ref_named(pcc, vars)), subset(partial, select = -network), reference = "graphicalVAR",
                   covers = c("fit_rolling_graphical_var()", "matrices.rolling_gvar_result()"),
                   quantity = "Aisha, last window, partial contemporaneous correlations", tolerance = 1e-6,
                   key = c("from", "to"))
})
