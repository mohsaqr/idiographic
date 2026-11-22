# Reference computations shared by the equivalence tests, written in base R. Nothing here calls
# idiographic: each function shapes one side of a comparison, and the package is the other.

#' The undirected edges of a symmetric matrix, one row per pair of the upper triangle
#'
#' @param cells A symmetric matrix with the variables as dimnames.
#' @param name The name of the value column.
#' @return A data frame `from`, `to`, `<name>`; `from` is the row variable.
ref_undirected <- function(cells, name = "weight") {
  stopifnot("`cells` must be a square matrix with dimnames" = is.matrix(cells) && nrow(cells) == ncol(cells) &&
              !is.null(rownames(cells)) && !is.null(colnames(cells)))
  pair <- which(upper.tri(cells), arr.ind = TRUE)
  out <- data.frame(from = rownames(cells)[pair[, "row"]], to = colnames(cells)[pair[, "col"]],
                    value = cells[pair], stringsAsFactors = FALSE)
  names(out)[[3L]] <- name
  out
}

#' The directed edges of a coefficient matrix, one row per cell
#'
#' @param cells A matrix with one row per outcome and one column per lagged predictor.
#' @param name The name of the value column.
#' @return A data frame `from` (the predictor), `to` (the outcome), `<name>`.
ref_directed <- function(cells, name = "weight") {
  stopifnot("`cells` must be a matrix with dimnames" = is.matrix(cells) && !is.null(rownames(cells)) &&
              !is.null(colnames(cells)))
  out <- data.frame(from = colnames(cells)[as.vector(col(cells))], to = rownames(cells)[as.vector(row(cells))],
                    value = as.vector(cells), stringsAsFactors = FALSE)
  names(out)[[3L]] <- name
  out
}

#' The edge table of a lag-1 network: the temporal coefficients and an undirected layer or two
#'
#' @param temporal A matrix, one row per outcome and one column per lagged predictor.
#' @param ... Named symmetric matrices (`contemporaneous`, `between`).
#' @return A data frame `network`, `from`, `to`, `weight`.
ref_network <- function(temporal, ...) {
  layers <- list(...)
  undirected <- Map(\(cells, layer) cbind(network = layer, ref_undirected(cells)), layers, names(layers))
  do.call(rbind, c(list(cbind(network = "temporal", ref_directed(temporal))), unname(undirected)))
}

#' Partial correlations from a precision matrix
#'
#' @param precision A precision matrix.
#' @return The matrix of partial correlations, with a zero diagonal.
ref_partial <- function(precision) {
  partial <- -stats::cov2cor(precision)
  diag(partial) <- 0
  partial
}

#' A series' rows with the previous occasion beside them
#'
#' @param series A data frame of one person's variables, in time order with no gap.
#' @return A data frame: the variables at occasions 2 to n, and `<variable>_lag` at occasions 1 to n - 1.
ref_lagged <- function(series) {
  today <- series[-1L, , drop = FALSE]
  yesterday <- stats::setNames(series[-nrow(series), , drop = FALSE], paste0(names(series), "_lag"))
  data.frame(today, yesterday, row.names = NULL)
}

#' A square matrix with the same names on both sides
#'
#' @param cells A square matrix.
#' @param names The variable names.
#' @return `cells` with `names` as row and column names.
ref_named <- function(cells, names) {
  dimnames(cells) <- list(names, names)
  cells
}

#' A first-order vector autoregression driven by given shocks
#'
#' @param shocks A matrix of shocks, one row per occasion; the first row is the first state.
#' @param transition The transition matrix (outcome rows, predictor columns).
#' @return A matrix of states, one row per occasion.
ref_var1 <- function(shocks, transition) {
  stopifnot("`transition` must be square with one row per column of `shocks`" =
              is.matrix(transition) && nrow(transition) == ncol(shocks) && ncol(transition) == ncol(shocks))
  states <- Reduce(\(previous, shock) as.vector(transition %*% previous) + shock,
                   asplit(shocks[-1L, , drop = FALSE], 1L), accumulate = TRUE, init = shocks[1L, ])
  do.call(rbind, states)
}

#' A simulated panel: one stationary VAR(1) per person around a person-specific mean
#'
#' Occasions are numbered by `day` and `beep` (`beeps` occasions a day).
#' @param n_id,days,beeps People, days per person and occasions per day.
#' @param vars The variable names.
#' @param transition The transition matrix (default: `ar` on the diagonal).
#' @param ar The autoregression used when `transition` is not given.
#' @param between_sd The standard deviation of the person means.
#' @param seed The seed.
#' @return A data frame `id`, `day`, `beep` and one column per variable.
ref_panel <- function(n_id = 12L, days = 4L, beeps = 12L, vars = c("A", "B", "C"), transition = NULL,
                      ar = 0.35, between_sd = 0.5, seed = 1L) {
  set.seed(seed)
  p <- length(vars)
  transition <- transition %||% diag(ar, p)
  n_t <- days * beeps
  people <- lapply(seq_len(n_id), \(person) {
    means <- stats::rnorm(p, 0, between_sd)
    states <- ref_var1(matrix(stats::rnorm(n_t * p), ncol = p), transition)
    series <- stats::setNames(as.data.frame(sweep(states, 2L, means, "+")), vars)
    data.frame(id = person, day = rep(seq_len(days), each = beeps), beep = rep(seq_len(beeps), days), series)
  })
  do.call(rbind, people)
}

#' mlVAR's three networks as idiographic's edge table: the temporal fixed effects (`Beta`, one row per outcome),
#' and the partial correlations of the residuals (`Theta`) and of the person means (`Omega_mu`)
mlvar_networks <- function(fit) {
  vars <- dimnames(fit$results$Beta$mean)[[1L]]
  ref_network(temporal = ref_named(fit$results$Beta$mean[, , 1L], vars),
              contemporaneous = ref_named(fit$results$Theta$pcor$mean, vars),
              between = ref_named(fit$results$Omega_mu$pcor$mean, vars))
}

#' Node strengths of an edge table (network, from, to, weight), from their definition
#'
#' Directed networks are those whose name starts with "temporal": out-strength sums the absolute weights of a
#' node's outgoing edges, in-strength of its incoming ones, self-loops apart (reported as `self`); strength is
#' their sum. In an undirected network strength sums the absolute weights of the node's edges.
#' @param edges A data frame `network`, `from`, `to`, `weight` holding every cell (zeros included).
#' @param vars The node names.
#' @return One row per network and node: `network`, `node`, `strength`, `out_strength`, `in_strength`, `self`.
ref_nodes <- function(edges, vars) {
  rows <- lapply(split(edges, factor(edges$network, unique(edges$network))), \(net) {
    directed <- startsWith(net$network[[1L]], "temporal")
    loops <- net$from == net$to
    self <- vapply(vars, \(node) sum(net$weight[loops & net$from == node]), numeric(1))
    out <- vapply(vars, \(node) sum(abs(net$weight[!loops & net$from == node])), numeric(1))
    into <- vapply(vars, \(node) sum(abs(net$weight[!loops & net$to == node])), numeric(1))
    data.frame(network = net$network[[1L]], node = vars,
               strength = if (directed) out + into else out + into,
               out_strength = if (directed) out else NA_real_, in_strength = if (directed) into else NA_real_,
               self = self, row.names = NULL)
  })
  do.call(rbind, rows)
}

#' Per-network counts and mean weight of an edge table, from their definition
#'
#' Edges are the non-zero weights between two different nodes; density divides their number by n (n - 1) in a
#' directed network and by n (n - 1) / 2 in an undirected one.
#' @inheritParams ref_nodes
#' @return One row per network: `network`, `n_nodes`, `n_edges`, `density`, `mean_abs_weight`, `n_positive`,
#'   `n_negative`.
ref_network_summary <- function(edges, vars) {
  rows <- lapply(split(edges, factor(edges$network, unique(edges$network))), \(net) {
    directed <- startsWith(net$network[[1L]], "temporal")
    n <- length(vars)
    w <- net$weight[net$from != net$to & net$weight != 0]
    possible <- if (directed) n * (n - 1) else n * (n - 1) / 2
    data.frame(network = net$network[[1L]], n_nodes = n, n_edges = length(w), density = length(w) / possible,
               mean_abs_weight = if (length(w)) mean(abs(w)) else 0, n_positive = sum(w > 0), n_negative = sum(w < 0))
  })
  do.call(rbind, rows)
}

#' One network layer of an edge table as an igraph graph: the non-zero cells between two different nodes
#'
#' @param net The rows of one network of an edge table (`network`, `from`, `to`, `weight`).
#' @param vars The node names.
#' @param directed Whether the layer is directed (from row to column).
#' @return An igraph graph with the signed weights as `weight`.
igraph_layer <- function(net, vars, directed) {
  kept <- net[net$from != net$to & net$weight != 0, c("from", "to", "weight")]
  igraph::graph_from_data_frame(kept, directed = directed, vertices = data.frame(name = vars))
}

#' Node strengths of an edge table computed by igraph::strength() on the absolute weights
#'
#' The same layout as ref_nodes(); `self` is the signed weight of the node's self-loop, read off the table.
#' @inheritParams ref_nodes
igraph_nodes <- function(edges, vars) {
  rows <- lapply(split(edges, factor(edges$network, unique(edges$network))), \(net) {
    directed <- startsWith(net$network[[1L]], "temporal")
    graph <- igraph_layer(net, vars, directed)
    strength <- \(mode) unname(igraph::strength(graph, vids = vars, mode = mode, loops = FALSE,
                                                weights = abs(igraph::E(graph)$weight)))
    loops <- net[net$from == net$to, ]
    self <- vapply(vars, \(node) sum(loops$weight[loops$from == node]), numeric(1))
    data.frame(network = net$network[[1L]], node = vars, strength = strength("all"),
               out_strength = if (directed) strength("out") else NA_real_,
               in_strength = if (directed) strength("in") else NA_real_, self = unname(self), row.names = NULL)
  })
  do.call(rbind, rows)
}

#' Per-network counts, density and mean weight of an edge table computed by igraph
#'
#' The same layout as ref_network_summary(): igraph::vcount(), igraph::ecount(), igraph::edge_density() and the
#' edge weights igraph holds.
#' @inheritParams ref_nodes
igraph_summary <- function(edges, vars) {
  rows <- lapply(split(edges, factor(edges$network, unique(edges$network))), \(net) {
    graph <- igraph_layer(net, vars, startsWith(net$network[[1L]], "temporal"))
    w <- igraph::E(graph)$weight
    data.frame(network = net$network[[1L]], n_nodes = igraph::vcount(graph), n_edges = igraph::ecount(graph),
               density = igraph::edge_density(graph, loops = FALSE),
               mean_abs_weight = if (length(w)) mean(abs(w)) else 0, n_positive = sum(w > 0), n_negative = sum(w < 0))
  })
  do.call(rbind, rows)
}

#' Mean error, RMSE and MAE of predictions computed by forecast::accuracy()
#'
#' forecast::accuracy() defines the error as observed minus forecast, as idiographic does.
#' @param observed,predicted The observed values and their predictions.
#' @return A one-row data frame `n`, `bias`, `rmse`, `mae`.
forecast_errors <- function(observed, predicted) {
  measures <- forecast::accuracy(predicted, observed)
  data.frame(n = length(observed), bias = measures[1L, "ME"], rmse = measures[1L, "RMSE"], mae = measures[1L, "MAE"])
}
