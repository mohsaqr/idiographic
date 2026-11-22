# extract_edges(), and edges(), nodes(), matrices(), as.data.frame() of a network object: the edge list, node
# strengths and weight matrix of a network given as a weight matrix, written here from their definitions.
#
# A network object is a list with `weights` (rows are the source, columns the target), the node labels in
# `nodes$label`, `method` and `directed`;
# one is built here by hand (class "netobject", or "cograph_network" as cograph builds it), and a group of them
# from fit_var(), whose weights test-var.R checks against stats::lm(). Definitions: the edges of a directed
# network are its non-zero cells off the diagonal, from row to column; of an undirected one, the non-zero cells
# of the upper triangle. A node's out-strength sums the absolute weights of its row, its in-strength those of its
# column (the diagonal apart, reported as `self`); undirected strength sums its row.
#
# Copies and sums of a few numbers: 1e-12; 1e-10 where the weights come from least squares (as in test-var.R).

abc <- c("A", "B", "C")
directed_weights <- matrix(c(0, 0.3, -0.2, 0.5, 0.1, 0, 0, -0.4, 0.2), 3L, 3L, dimnames = list(abc, abc))
undirected_weights <- matrix(c(0, 0.3, -0.2, 0.3, 0, 0, -0.2, 0, 0), 3L, 3L, dimnames = list(abc, abc))

#' The edge list of a weight matrix from its definition
matrix_edges <- function(weights, directed, include_self = FALSE) {
  keep <- weights != 0 & (if (directed) (row(weights) != col(weights) | include_self) else upper.tri(weights))
  cells <- which(keep, arr.ind = TRUE)
  data.frame(from = rownames(weights)[cells[, "row"]], to = colnames(weights)[cells[, "col"]], weight = weights[cells])
}

#' The node strengths of a weight matrix from their definition
matrix_strengths <- function(weights, directed) {
  off <- abs(weights)
  diag(off) <- 0
  out <- rowSums(off)
  into <- colSums(off)
  data.frame(node = rownames(weights), strength = if (directed) out + into else out,
             out_strength = if (directed) out else NA_real_, in_strength = if (directed) into else NA_real_,
             self = diag(weights))
}

test_that("a directed network given as a weight matrix", {
  hand_built <- structure(list(weights = directed_weights, nodes = data.frame(label = abc), method = "relative",
                               directed = TRUE), class = "netobject")
  expect_reference(extract_edges(hand_built), matrix_edges(directed_weights, TRUE),
                   reference = "independent: non-zero cells of the weight matrix", covers = "extract_edges()",
                   quantity = "directed, without self-loops", tolerance = 1e-12, key = c("from", "to"))
  expect_reference(extract_edges(hand_built, include_self = TRUE), matrix_edges(directed_weights, TRUE, TRUE),
                   reference = "independent: non-zero cells of the weight matrix", covers = "extract_edges()",
                   quantity = "directed, with self-loops", tolerance = 1e-12, key = c("from", "to"))
  expect_reference(edges(hand_built), matrix_edges(directed_weights, TRUE),
                   reference = "independent: non-zero cells of the weight matrix", covers = "edges.netobject()",
                   quantity = "directed edges", tolerance = 1e-12, key = c("from", "to"))
  expect_reference(as.data.frame(hand_built), matrix_edges(directed_weights, TRUE),
                   reference = "independent: non-zero cells of the weight matrix", covers = "as.data.frame.netobject()",
                   quantity = "directed edges, the data frame of the network", tolerance = 1e-12, key = c("from", "to"))
  expect_reference(nodes(hand_built), matrix_strengths(directed_weights, TRUE),
                   reference = "independent: row and column sums of the absolute weights", covers = "nodes.netobject()",
                   quantity = "directed node strengths", tolerance = 1e-12, key = "node")
  # API gap: matrices() returns a list of matrices, so the weight matrix is reached by name.
  expect_reference(matrices(hand_built, print = FALSE)[["weights"]], directed_weights,
                   reference = "independent: the weight matrix given", covers = "matrices.netobject()",
                   quantity = "directed weight matrix", tolerance = 1e-12)
  as_cograph <- structure(list(weights = directed_weights, method = "relative", directed = TRUE),
                          class = "cograph_network")
  expect_reference(matrices(as_cograph, print = FALSE)[["weights"]], directed_weights,
                   reference = "independent: the weight matrix given", covers = "matrices.cograph_network()",
                   quantity = "directed weight matrix of a cograph network", tolerance = 1e-12)
  expect_reference(extract_edges(as_cograph), matrix_edges(directed_weights, TRUE),
                   reference = "independent: non-zero cells of the weight matrix", covers = "extract_edges()",
                   quantity = "directed edges of a cograph network", tolerance = 1e-12, key = c("from", "to"))
})

test_that("an undirected network given as a weight matrix", {
  hand_built <- structure(list(weights = undirected_weights, nodes = data.frame(label = abc), method = "glasso",
                               directed = FALSE), class = "netobject")
  expect_reference(extract_edges(hand_built), matrix_edges(undirected_weights, FALSE),
                   reference = "independent: non-zero cells of the weight matrix", covers = "extract_edges()",
                   quantity = "undirected, upper triangle", tolerance = 1e-12, key = c("from", "to"))
  expect_reference(nodes(hand_built), matrix_strengths(undirected_weights, FALSE),
                   reference = "independent: row and column sums of the absolute weights", covers = "nodes.netobject()",
                   quantity = "undirected node strengths", tolerance = 1e-12, key = "node")
})

test_that("a group of networks: the temporal and contemporaneous networks of fit_var()", {
  items <- c("efficacy", "planning", "effort")
  learner <- subset(esm_srl, name == "Tariq", select = c(occasion, efficacy, planning, effort))
  group <- as_netobject(fit_var(learner, vars = items, beep = "occasion"))
  lagged <- ref_lagged(as.data.frame(scale(learner[items])))
  model <- stats::lm(stats::as.formula(sprintf("cbind(%s) ~ %s", toString(items), paste0(items, "_lag", collapse = " + "))),
                     data = lagged)
  # coef(): one row per lagged predictor, one column per outcome: the source-by-target weight matrix.
  temporal <- ref_named(stats::coef(model)[-1L, , drop = FALSE], items)
  partial <- ref_named(ref_partial(solve(stats::cov(stats::residuals(model)))), items)
  theirs <- rbind(cbind(network = "temporal", matrix_edges(temporal, TRUE)),
                  cbind(network = "contemporaneous", matrix_edges(partial, FALSE)))
  expect_reference(edges(group), theirs, reference = "stats",
                   covers = c("edges.netobject_group()", "as_netobject()", "as_netobject.var_result()"),
                   quantity = "Tariq, both networks", tolerance = 1e-10, key = c("network", "from", "to"))
  expect_reference(as.data.frame(group), theirs, reference = "stats", covers = "as.data.frame.netobject_group()",
                   quantity = "Tariq, both networks, the data frame of the group", tolerance = 1e-10,
                   key = c("network", "from", "to"))
  strengths <- rbind(cbind(network = "temporal", matrix_strengths(temporal, TRUE)),
                     cbind(network = "contemporaneous", matrix_strengths(partial, FALSE)))
  expect_reference(nodes(group), strengths, reference = "stats", covers = "nodes.netobject_group()",
                   quantity = "Tariq, node strengths of both networks", tolerance = 1e-10, key = c("network", "node"))
  # API gap: matrices() returns a list of matrices, so each network is reached by name.
  expect_reference(matrices(group, print = FALSE)[["temporal"]], temporal, reference = "stats",
                   covers = "matrices.netobject_group()", quantity = "Tariq, temporal weights (source rows)",
                   tolerance = 1e-10)
  expect_reference(matrices(group, print = FALSE)[["contemporaneous"]], partial, reference = "stats",
                   covers = "matrices.netobject_group()", quantity = "Tariq, contemporaneous partial correlations",
                   tolerance = 1e-10)
})

#' The edge list igraph reads from a weight matrix: rows are sources in a directed network, the upper triangle
#' in an undirected one; igraph keeps the non-zero cells only
igraph_edges <- function(weights, directed, include_self = FALSE) {
  graph <- igraph::graph_from_adjacency_matrix(weights, mode = if (directed) "directed" else "upper",
                                               weighted = TRUE, diag = include_self)
  stats::setNames(igraph::as_data_frame(graph, what = "edges")[c("from", "to", "weight")], c("from", "to", "weight"))
}

#' Node strengths of a weight matrix by igraph::strength() on the absolute weights (self-loops apart)
igraph_strengths <- function(weights, directed) {
  graph <- igraph::graph_from_adjacency_matrix(abs(weights), mode = if (directed) "directed" else "upper",
                                               weighted = TRUE, diag = FALSE)
  strength <- \(mode) unname(igraph::strength(graph, mode = mode, loops = FALSE))
  data.frame(node = rownames(weights), strength = strength("all"),
             out_strength = if (directed) strength("out") else NA_real_,
             in_strength = if (directed) strength("in") else NA_real_, self = unname(diag(weights)))
}

test_that("edge lists and strengths of the hand-built networks, by igraph", {
  directed <- structure(list(weights = directed_weights, nodes = data.frame(label = abc), method = "relative",
                             directed = TRUE), class = "netobject")
  undirected <- structure(list(weights = undirected_weights, nodes = data.frame(label = abc), method = "glasso",
                               directed = FALSE), class = "netobject")
  expect_reference(extract_edges(directed), igraph_edges(directed_weights, TRUE), reference = "igraph",
                   covers = "extract_edges()", quantity = "directed, without self-loops, igraph", tolerance = 1e-12,
                   key = c("from", "to"))
  expect_reference(extract_edges(directed, include_self = TRUE), igraph_edges(directed_weights, TRUE, TRUE),
                   reference = "igraph", covers = "extract_edges()", quantity = "directed, with self-loops, igraph",
                   tolerance = 1e-12, key = c("from", "to"))
  expect_reference(edges(directed), igraph_edges(directed_weights, TRUE), reference = "igraph",
                   covers = "edges.netobject()", quantity = "directed edges, igraph", tolerance = 1e-12,
                   key = c("from", "to"))
  expect_reference(as.data.frame(undirected), igraph_edges(undirected_weights, FALSE), reference = "igraph",
                   covers = c("as.data.frame.netobject()", "edges.netobject()"),
                   quantity = "undirected edges, igraph", tolerance = 1e-12, key = c("from", "to"))
  expect_reference(nodes(directed), igraph_strengths(directed_weights, TRUE), reference = "igraph",
                   covers = "nodes.netobject()", quantity = "directed node strengths, igraph", tolerance = 1e-12,
                   key = "node")
  expect_reference(nodes(undirected), igraph_strengths(undirected_weights, FALSE), reference = "igraph",
                   covers = "nodes.netobject()", quantity = "undirected node strengths, igraph", tolerance = 1e-12,
                   key = "node")
})

test_that("a network object estimated elsewhere: the transition network of tna's group_regulation", {
  # Nestimate::build_network() builds the network object (class netobject); its weights are the row-normalised
  # transition frequencies, compared with tna::tna() (the gold standard) on the same sequences.
  network <- Nestimate::build_network(tna::group_regulation, method = "relative")
  transitions <- tna::tna(tna::group_regulation)$weights
  # API gap: matrices() returns a list of matrices, so the weight matrix is reached by name.
  expect_reference(matrices(network, print = FALSE)[["weights"]], unclass(transitions), reference = "tna",
                   covers = "matrices.netobject()", quantity = "group_regulation, transition probabilities",
                   tolerance = 1e-12,
                   note = "The network object is built by Nestimate::build_network(method = 'relative'); its weights are compared with tna::tna().")
  weights <- unclass(transitions)
  expect_reference(edges(network), igraph_edges(weights, TRUE), reference = "igraph", covers = "edges.netobject()",
                   quantity = "group_regulation, edges (igraph on tna's weights)", tolerance = 1e-12,
                   key = c("from", "to"))
  expect_reference(as.data.frame(network), igraph_edges(weights, TRUE), reference = "igraph",
                   covers = "as.data.frame.netobject()",
                   quantity = "group_regulation, the data frame of the network (igraph on tna's weights)",
                   tolerance = 1e-12, key = c("from", "to"))
  expect_reference(extract_edges(network), igraph_edges(weights, TRUE), reference = "igraph",
                   covers = "extract_edges()", quantity = "group_regulation, extract_edges() (igraph on tna's weights)",
                   tolerance = 1e-12, key = c("from", "to"))
  expect_reference(nodes(network), igraph_strengths(weights, TRUE), reference = "igraph",
                   covers = "nodes.netobject()", quantity = "group_regulation, node strengths (igraph on tna's weights)",
                   tolerance = 1e-12, key = "node")
  # as_netobject() of a network object returns it; of a bare cograph network it wraps the weights.
  expect_reference(matrices(as_netobject(network), print = FALSE)[["weights"]], weights, reference = "tna",
                   covers = c("as_netobject()", "as_netobject.netobject()"),
                   quantity = "group_regulation, as_netobject() of the network object", tolerance = 1e-12)
  bare <- structure(list(weights = weights, method = "relative", directed = TRUE), class = "cograph_network")
  expect_reference(matrices(as_netobject(bare), print = FALSE)[["weights"]], weights, reference = "tna",
                   covers = "as_netobject.cograph_network()",
                   quantity = "group_regulation, as_netobject() of a cograph network holding tna's weights",
                   tolerance = 1e-12)
})

test_that("the network object of a graphical VAR holds graphicalVAR's weights, source rows", {
  items <- c("efficacy", "planning", "effort")
  learner <- subset(esm_srl, name == "Tariq", select = c(occasion, efficacy, planning, effort))
  group <- as_netobject(fit_graphical_var(learner, vars = items, beep = "occasion", n_lambda = 15, gamma = 0))
  gvar <- graphicalVAR::graphicalVAR(learner, vars = items, beepvar = "occasion", nLambda = 15, gamma = 0,
                                     verbose = FALSE)
  # graphicalVAR's beta: one row per outcome, the intercept first; the network reads predictor rows.
  # 1e-4: graphicalVAR stops its glasso at thr = 1e-4 (test-graphical-var.R).
  temporal <- group[["temporal"]]
  expect_reference(matrices(temporal, print = FALSE)[["weights"]], t(ref_named(gvar$beta[, -1L], items)),
                   reference = "graphicalVAR", covers = c("matrices.cograph_network()", "as_netobject.gvar_result()"),
                   quantity = "Tariq, temporal network of the graphical VAR (source rows)", tolerance = 1e-4,
                   note = "API gap: the layer is reached by name in the network group.")
  contemporaneous <- group[["contemporaneous"]]
  expect_reference(matrices(contemporaneous, print = FALSE)[["weights"]], ref_named(gvar$PCC, items),
                   reference = "graphicalVAR", covers = c("matrices.cograph_network()", "as_netobject.gvar_result()"),
                   quantity = "Tariq, contemporaneous network of the graphical VAR", tolerance = 1e-4)
})
