# compare_idiographic(): one network summary per estimator and layer on the same series. The VAR side against
# stats::lm() on the lagged, standardised series (as test-var.R); the graphical VAR side against
# graphicalVAR::graphicalVAR() 0.4.1 with the same grid and EBIC gamma (as test-graphical-var.R). Of each layer's
# summary, the node and edge counts and the density are igraph's (vcount, ecount, edge_density of the reference's
# weight matrix); the weight summaries (mean and largest |weight|, signs, self-loops) are written from their
# definitions and declared as such.
#
# Tolerances: 1e-10 for the least-squares side (rounding only); 1e-4 for the graphical VAR side, the bound of the
# package's fixture test against graphicalVAR on this learner (graphicalVAR stops its glasso at thr = 1e-4).

items <- c("efficacy", "planning", "effort")

#' One layer's weight summaries from its weight matrix (source rows): edges are the non-zero cells off the
#' diagonal (directed) or of the upper triangle (undirected); the self-loops are the non-zero diagonal of a
#' directed layer.
layer_summary <- function(cells, layer, directed) {
  off <- if (directed) row(cells) != col(cells) else upper.tri(cells)
  w <- cells[off & cells != 0]
  self <- if (directed) diag(cells)[diag(cells) != 0] else numeric(0)
  data.frame(network = layer, mean_abs_weight = if (length(w)) mean(abs(w)) else 0, n_positive = sum(w > 0),
             n_negative = sum(w < 0), n_self = length(self), max_abs_weight = max(abs(c(w, self)), 0))
}

#' One layer's node count, edge count and density by igraph, from the same weight matrix (self-loops apart)
igraph_layer <- function(cells, layer, directed) {
  graph <- igraph::graph_from_adjacency_matrix(cells, mode = if (directed) "directed" else "upper",
                                               weighted = TRUE, diag = FALSE)
  data.frame(network = layer, n_nodes = igraph::vcount(graph), n_edges = igraph::ecount(graph),
             density = igraph::edge_density(graph, loops = FALSE))
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
  var_temporal <- ref_named(stats::coef(model)[-1L, ], items)
  # psych::partial.r() of the residual correlations: the contemporaneous partial correlations, no self-loops.
  var_partial <- ref_named(unclass(psych::partial.r(stats::cov2cor(stats::cov(stats::residuals(model))))), items)
  diag(var_partial) <- 0
  var_ours <- subset(as.data.frame(comparison), method == "var", select = -method)
  expect_reference(var_ours, rbind(igraph_layer(var_temporal, "temporal", TRUE),
                                   igraph_layer(var_partial, "contemporaneous", FALSE)),
                   reference = "igraph", covers = c("compare_idiographic()", "as.data.frame.model_comparison()"),
                   quantity = "Tariq, VAR layers: nodes, edges, density (igraph on the stats::lm() and psych::partial.r() matrices)",
                   tolerance = 1e-10, key = "network")
  expect_reference(var_ours, rbind(layer_summary(var_temporal, "temporal", TRUE),
                                   layer_summary(var_partial, "contemporaneous", FALSE)),
                   reference = "independent: weight summaries of the stats::lm() VAR layers, from their definitions",
                   covers = c("compare_idiographic()", "as.data.frame.model_comparison()"),
                   quantity = "Tariq, VAR layers: weight summaries", tolerance = 1e-10, key = "network")
  gvar <- graphicalVAR::graphicalVAR(learner, vars = items, beepvar = "occasion", nLambda = 15, gamma = 0,
                                     verbose = FALSE)
  gvar_temporal <- t(ref_named(gvar$beta[, -1L], items))
  gvar_partial <- ref_named(gvar$PCC, items)
  gvar_ours <- subset(summary(comparison), method == "graphical_var", select = -method)
  expect_reference(gvar_ours, rbind(igraph_layer(gvar_temporal, "temporal", TRUE),
                                    igraph_layer(gvar_partial, "contemporaneous", FALSE)),
                   reference = "igraph", covers = c("compare_idiographic()", "summary.model_comparison()"),
                   quantity = "Tariq, graphical VAR layers: nodes, edges, density (igraph on graphicalVAR's matrices)",
                   tolerance = 1e-4, key = "network")
  expect_reference(gvar_ours, rbind(layer_summary(gvar_temporal, "temporal", TRUE),
                                    layer_summary(gvar_partial, "contemporaneous", FALSE)),
                   reference = "independent: weight summaries of graphicalVAR's layers, from their definitions",
                   covers = c("compare_idiographic()", "summary.model_comparison()"),
                   quantity = "Tariq, graphical VAR layers: weight summaries", tolerance = 1e-4, key = "network")
  # API gap: matrices() returns a list of matrices, so the residual covariance is reached by name.
  expect_reference(matrices(comparison, fit = 1L, print = FALSE)[["residual_cov"]],
                   ref_named(stats::cov(stats::residuals(model)), items), reference = "stats",
                   covers = c("matrices.model_comparison()", "compare_idiographic()"),
                   quantity = "Tariq, the stored VAR's residual covariance", tolerance = 1e-10)
})
