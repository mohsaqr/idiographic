# compare_idiographic(): one network summary per estimator and layer on the same series. The VAR side against
# stats::lm() on the lagged, standardised series (as test-var.R); the graphical VAR side against
# graphicalVAR::graphicalVAR() 0.4.1 with the same grid and EBIC gamma (as test-graphical-var.R); the counts,
# density and weights of each layer then from their definitions.
#
# Tolerances: 1e-10 for the least-squares side (rounding only); 1e-4 for the graphical VAR side, the bound of the
# package's fixture test against graphicalVAR on this learner (graphicalVAR stops its glasso at thr = 1e-4).

items <- c("efficacy", "planning", "effort")

#' One layer's summary from its weight matrix (source rows): edges are the non-zero cells off the diagonal
#' (directed) or of the upper triangle (undirected); the self-loops are the non-zero diagonal of a directed layer.
layer_summary <- function(cells, layer, directed) {
  n <- nrow(cells)
  off <- if (directed) row(cells) != col(cells) else upper.tri(cells)
  w <- cells[off & cells != 0]
  self <- if (directed) diag(cells)[diag(cells) != 0] else numeric(0)
  data.frame(network = layer, n_nodes = n, n_edges = length(w),
             density = length(w) / (if (directed) n * (n - 1) else n * (n - 1) / 2),
             mean_abs_weight = if (length(w)) mean(abs(w)) else 0, n_positive = sum(w > 0), n_negative = sum(w < 0),
             n_self = length(self), max_abs_weight = max(abs(c(w, self)), 0))
}

test_that("the VAR and graphical VAR summaries of one learner's diary", {
  skip_without_reference("graphicalVAR")
  learner <- subset(esm_srl, name == "Tariq", select = c(occasion, efficacy, planning, effort))
  comparison <- compare_idiographic(learner, vars = items, estimators = c("var", "graphical_var"), beep = "occasion",
                                    estimator_args = list(graphical_var = list(n_lambda = 15, gamma = 0)),
                                    keep_fits = TRUE)
  lagged <- ref_lagged(as.data.frame(scale(learner[items])))
  model <- stats::lm(stats::as.formula(sprintf("cbind(%s) ~ %s", toString(items), paste0(items, "_lag", collapse = " + "))),
                     data = lagged)
  var_layers <- rbind(layer_summary(ref_named(stats::coef(model)[-1L, ], items), "temporal", TRUE),
                      layer_summary(ref_named(ref_partial(solve(stats::cov(stats::residuals(model)))), items),
                                    "contemporaneous", FALSE))
  expect_reference(subset(as.data.frame(comparison), method == "var", select = -method), var_layers,
                   reference = "stats", covers = c("compare_idiographic()", "as.data.frame.model_comparison()"),
                   quantity = "Tariq, VAR layers", tolerance = 1e-10, key = "network")
  gvar <- graphicalVAR::graphicalVAR(learner, vars = items, beepvar = "occasion", nLambda = 15, gamma = 0,
                                     verbose = FALSE)
  gvar_layers <- rbind(layer_summary(t(ref_named(gvar$beta[, -1L], items)), "temporal", TRUE),
                       layer_summary(ref_named(gvar$PCC, items), "contemporaneous", FALSE))
  expect_reference(subset(summary(comparison), method == "graphical_var", select = -method), gvar_layers,
                   reference = "graphicalVAR", covers = c("compare_idiographic()", "summary.model_comparison()"),
                   quantity = "Tariq, graphical VAR layers", tolerance = 1e-4, key = "network")
  # API gap: matrices() returns a list of matrices, so the residual covariance is reached by name.
  expect_reference(matrices(comparison, fit = 1L, print = FALSE)[["residual_cov"]],
                   ref_named(stats::cov(stats::residuals(model)), items), reference = "stats",
                   covers = c("matrices.model_comparison()", "compare_idiographic()"),
                   quantity = "Tariq, the stored VAR's residual covariance", tolerance = 1e-10)
})
