# Self-contained helpers so idiographic depends on NO other package of this
# ecosystem (no Nestimate import). These vendor the small pieces the estimators
# need: cograph_network constructors, grouped cograph objects, and netobject
# compatibility classes where cograph still uses them for plotting dispatch.

#' Edge index for a weight matrix -- the single source of truth for "which
#' cells are edges", so every accessor shares one diagonal/triangle/NA rule.
#'
#' Directed: every non-zero off-diagonal cell, plus the diagonal when
#' `include_self`. Undirected: each pair once (upper triangle), including the
#' diagonal only when `include_self`. NA cells are never edges. `keep_zeros`
#' lists every structural cell (the full coefficient table) regardless of value.
#' @return A two-column (row, col) integer matrix, as `which(arr.ind = TRUE)`.
#' @keywords internal
#' @noRd
.net_edge_idx <- function(W, directed, include_self = FALSE,
                          keep_zeros = FALSE) {
  present <- if (keep_zeros) matrix(TRUE, nrow(W), ncol(W)) else
    (!is.na(W) & W != 0)
  if (directed) {
    mask <- if (include_self) present else present & (row(W) != col(W))
  } else {
    tri  <- if (include_self) row(W) <= col(W) else row(W) < col(W)
    mask <- present & tri
  }
  which(mask, arr.ind = TRUE)
}

#' @keywords internal
#' @noRd
.ido_edges <- function(mat, directed = FALSE) {
  idx <- .net_edge_idx(mat, directed, include_self = TRUE)
  if (nrow(idx) == 0L) {
    return(data.frame(from = integer(0), to = integer(0),
                      weight = numeric(0), stringsAsFactors = FALSE))
  }
  data.frame(from = as.integer(idx[, 1]), to = as.integer(idx[, 2]),
             weight = mat[idx], stringsAsFactors = FALSE)
}

#' Wrap a square weight matrix as a cograph_network / netobject
#'
#' Minimal, dependency-free constructor. Produces the fields that
#' `cograph::splot()` consumes for a standard cograph network, with `netobject`
#' retained as a compatibility class.
#' @keywords internal
#' @noRd
.ido_wrap <- function(mat, method = "idiographic", directed = TRUE) {
  if (!is.matrix(mat) || !is.numeric(mat)) {
    stop("'mat' must be a numeric matrix.", call. = FALSE)
  }
  if (nrow(mat) != ncol(mat)) {
    stop("'mat' must be a square matrix.", call. = FALSE)
  }
  states <- rownames(mat)
  if (is.null(states)) {
    states <- as.character(seq_len(nrow(mat)))
    dimnames(mat) <- list(states, states)
  }
  nodes_df <- data.frame(
    id = seq_along(states), label = states, name = states,
    x = NA_real_, y = NA_real_, stringsAsFactors = FALSE
  )
  edges <- .ido_edges(mat, directed = directed)
  structure(list(
    data = NULL, weights = mat, nodes = nodes_df, edges = edges,
    directed = directed, method = method, params = list(), scaling = NULL,
    threshold = 0, n_nodes = length(states), n_edges = nrow(edges),
    level = NULL,
    meta = list(source = "idiographic", layout = NULL, tna = list(method = method)),
    node_groups = NULL
  ), class = c("cograph_network", "netobject", "list"))
}

#' Coerce to a netobject
#'
#' Returns netobjects unchanged; promotes a bare `cograph_network`.
#' @param x A `netobject` or `cograph_network`.
#' @param ... Passed to methods.
#' @return A `c("netobject", "cograph_network")` object.
#' @export
as_netobject <- function(x, ...) UseMethod("as_netobject")

#' @export
as_netobject.netobject <- function(x, ...) x

#' @export
as_netobject.cograph_network <- function(x, ...) {
  if (inherits(x, "netobject")) return(x)
  # Preserve the plotting method whether it sits at the top level or nested in
  # meta$tna$method (some constructors only fill the nested slot); falling back
  # to "idiographic" would silently drop directedness cues in cograph.
  .ido_wrap(as.matrix(x$weights),
            method   = x$method %||% x$meta$tna$method %||% "idiographic",
            directed = x$directed %||% TRUE)
}

#' @export
as_netobject.default <- function(x, ...) {
  stop("as_netobject() needs a netobject or cograph_network; got <",
       paste(class(x), collapse = "/"), ">.", call. = FALSE)
}

#' @keywords internal
#' @noRd
`%||%` <- function(a, b) if (is.null(a)) b else a

#' Moore-Penrose pseudoinverse via SVD -- a base-R replica of
#' `corpcor::pseudoinverse()` (which routes square matrices through
#' `positive.svd`): same singular-value tolerance and trimming, so the mlVAR /
#' VAR network derivations stay numerically identical without the dependency.
#' @keywords internal
#' @noRd
.ido_pseudoinverse <- function(m, tol) {
  s <- svd(m)
  if (missing(tol)) tol <- max(dim(m)) * max(s$d) * .Machine$double.eps
  pos <- s$d > tol
  if (!any(pos)) return(array(0, dim(m)[2:1]))
  s$v[, pos, drop = FALSE] %*% (1 / s$d[pos] * t(s$u[, pos, drop = FALSE]))
}

#' Partial correlations from a covariance/correlation matrix -- base-R replica
#' of `corpcor::cor2pcor()` (`-pseudoinverse`, flip the diagonal sign, then
#' `cov2cor`), bit-for-bit on the square inputs used here.
#' @keywords internal
#' @noRd
.ido_cor2pcor <- function(m, tol) {
  m <- -.ido_pseudoinverse(m, tol)
  diag(m) <- -diag(m)
  stats::cov2cor(m)
}

#' Build an estimator result that is also a cograph group
#' @keywords internal
#' @noRd
.ido_group_result <- function(class, networks, model) {
  attr(networks, "model") <- model
  attr(networks, "group_col") <- "network_type"
  class(networks) <- c(class, "cograph_group", "netobject_group")
  networks
}

#' Return the network-only group view of an idiographic group result
#' @keywords internal
#' @noRd
.ido_network_group <- function(x) {
  structure(unclass(x), class = "netobject_group")
}

#' `$` compatibility for estimator metadata stored on cograph group results
#' @keywords internal
#' @noRd
.ido_result_dollar <- function(x, name) {
  model <- attr(x, "model", exact = TRUE)
  if (!is.null(model) && name %in% names(model)) return(model[[name]])
  unclass(x)[[name]]
}

#' @export
`$.gvar_result` <- function(x, name) .ido_result_dollar(x, name)

#' @export
`$.var_result` <- function(x, name) .ido_result_dollar(x, name)

#' @export
`$.net_usem` <- function(x, name) .ido_result_dollar(x, name)

#' Validate an optional column-name argument (NULL, or a single name in `data`)
#' @keywords internal
#' @noRd
.ido_check_col <- function(value, arg, data) {
  if (is.null(value)) return(invisible(NULL))
  if (!(is.character(value) && length(value) == 1L)) {
    stop("`", arg, "` must be NULL or a single column name.", call. = FALSE)
  }
  if (!value %in% names(data)) {
    stop("`", arg, "` column '", value, "' not found in data.", call. = FALSE)
  }
  invisible(NULL)
}

#' Validate a scalar logical argument
#' @keywords internal
#' @noRd
.ido_check_flag <- function(value, arg) {
  if (!(is.logical(value) && length(value) == 1L && !is.na(value))) {
    stop("`", arg, "` must be a single TRUE/FALSE value.", call. = FALSE)
  }
  invisible(NULL)
}

#' Validate model variables before numeric scaling / lag construction
#' @keywords internal
#' @noRd
.ido_check_numeric_vars <- function(data, vars, check_variance = TRUE) {
  bad_type <- vars[!vapply(data[vars], is.numeric, logical(1))]
  if (length(bad_type) > 0L) {
    stop("Variable(s) must be numeric to be modelled: ",
         paste(bad_type, collapse = ", "), ".", call. = FALSE)
  }
  if (!isTRUE(check_variance)) return(invisible(NULL))
  bad_var <- vars[vapply(vars, function(v) {
    s <- stats::sd(data[[v]], na.rm = TRUE)
    !is.finite(s) || s == 0
  }, logical(1))]
  if (length(bad_var) > 0L) {
    stop("Variable(s) with zero/non-finite variance cannot be modelled: ",
         paste(bad_var, collapse = ", "), ".", call. = FALSE)
  }
  invisible(NULL)
}

#' Select subjects for analysis: named ones and/or those with enough data.
#'
#' Shared by the estimators so `subject` / `min_obs` are arguments on the
#' modelling call rather than a separate preparation step. `subject` names the
#' exact people to analyse; `min_obs` keeps everyone with at least that many
#' observations (counts read from the data frame).
#' @keywords internal
#' @noRd
.ido_keep <- function(data, id, min_obs = NULL, subject = NULL) {
  if (is.null(min_obs) && is.null(subject)) return(data)
  if (is.null(id) || !is.data.frame(data)) {
    stop("'subject' / 'min_obs' require a data.frame with an 'id' column.",
         call. = FALSE)
  }
  if (!id %in% names(data)) {
    stop("id column '", id, "' not found in data.", call. = FALSE)
  }
  # min_obs must be a single whole number >= 1; invalid values used to either
  # keep everyone (<= 0) or silently drop everyone (NA / fractional), surfacing
  # only as a cryptic subscript error downstream.
  if (!is.null(min_obs)) {
    if (!(is.numeric(min_obs) && length(min_obs) == 1L &&
          is.finite(min_obs) && min_obs >= 1L &&
          min_obs == as.integer(min_obs))) {
      stop("`min_obs` must be a single finite whole number >= 1; got ",
           paste(format(min_obs), collapse = ", "), ".", call. = FALSE)
    }
  }
  if (!is.null(subject)) {
    bad <- setdiff(as.character(subject), as.character(data[[id]]))
    if (length(bad) > 0L) {
      stop("subject(s) not found in '", id, "': ",
           paste(bad, collapse = ", "), call. = FALSE)
    }
    data <- data[as.character(data[[id]]) %in% as.character(subject), ,
                 drop = FALSE]
  }
  if (!is.null(min_obs)) {
    counts <- table(data[[id]])
    keep <- names(counts)[counts >= min_obs]
    data <- data[as.character(data[[id]]) %in% keep, , drop = FALSE]
  }
  if (nrow(data) == 0L) {
    stop("No observations remain after applying `subject` / `min_obs` ",
         "filtering. Lower `min_obs` (currently ",
         if (is.null(min_obs)) "NULL" else min_obs, ") or check `subject`.",
         call. = FALSE)
  }
  data
}

#' Plottable netobjects from an mlVAR fit
#'
#' Returns the three networks as netobjects oriented for plotting
#' (temporal edges run predictor -> outcome, matching `graphical_var`), so
#' `cograph::splot()` renders them consistently. The raw `fit$temporal$weights`
#' keep mlVAR's `[outcome, predictor]` layout for equivalence.
#' @param x A `net_mlvar` object.
#' @param ... Unused.
#' @return A `netobject_group` with `$temporal`, `$contemporaneous`, `$between`.
#' @export
# cograph::splot decides directedness from the method name: "relative" renders
# directed (arrows), "co_occurrence" renders undirected. Custom names default to
# undirected, so use these two so temporal networks draw arrows.
as_netobject.net_mlvar <- function(x, ...) {
  structure(
    list(temporal        = .ido_wrap(t(x$temporal$weights), "relative", TRUE),
         contemporaneous = .ido_wrap(x$contemporaneous$weights, "co_occurrence", FALSE),
         between         = .ido_wrap(x$between$weights, "co_occurrence", FALSE)),
    class = "netobject_group")
}

#' Plottable netobject(s) from a GIMME fit
#'
#' Returns the GIMME result as matrix-backed netobjects. By default these encode
#' the **same quantity the `gimme` package plots** — the *proportion of subjects*
#' that have each path (`path_counts / n_subjects`) — not the group-average
#' coefficient (which dilutes toward zero and is not what GIMME displays). For
#' the faithful single mixed network (dashed lag / solid contemporaneous,
#' group/individual colouring, autoregressive self-loops) use [plot_gimme()].
#'
#' @param x A `net_gimme` object.
#' @param style Either `"pnode"` (default) — a `netobject_group` of two directed
#'   `p`-node networks, `$temporal` (lagged; autoregression on the diagonal) and
#'   `$contemporaneous` (same-beep), matching the shape [graphical_var()] returns
#'   — or `"unified"`, a single directed `2p`-node network with the `*_lag` half
#'   feeding the current half (the literal uSEM topology).
#' @param weight Either `"prop"` (default) — edge weight is the proportion of
#'   subjects with the path — or `"coef"`, the group-average standardized
#'   coefficient.
#' @param ... Unused.
#' @return For `style = "pnode"`, a `netobject_group` with `$temporal` and
#'   `$contemporaneous`. For `style = "unified"`, one
#'   `c("netobject", "cograph_network")` object with `2p` nodes.
#' @seealso [plot_gimme()] for the faithful gimme-style mixed plot.
#' @export
as_netobject.net_gimme <- function(x, style = c("pnode", "unified"),
                                   weight = c("prop", "coef"), ...) {
  style  <- match.arg(style)
  weight <- match.arg(weight)
  vars <- x$labels; p <- length(vars); n <- x$n_subjects

  # Under VAR / hybrid the contemporaneous component is an undirected residual-
  # covariance network (stored in $contemp_cov / $contemp_cov_avg), not the
  # directed lag-0 block (which is all-zero there).
  cov_mode <- isTRUE(x$contemp_is_cov)
  if (weight == "prop") {
    temp <- x$path_counts[, paste0(vars, "lag"), drop = FALSE] / n
    cont <- if (cov_mode) x$contemp_cov / n else
      x$path_counts[, vars, drop = FALSE] / n
  } else {
    temp <- x$temporal_avg
    cont <- if (cov_mode) x$contemp_cov_avg else x$contemporaneous_avg
  }
  dimnames(temp) <- dimnames(cont) <- list(vars, vars)  # [outcome, predictor]

  if (style == "pnode") {
    # Two p-node networks. Temporal is directed (transpose so edge weight
    # A[from, to] runs predictor -> outcome, autoregression on the diagonal).
    # Contemporaneous is directed for lag-0 regressions but UNDIRECTED when it
    # is a residual-covariance network (VAR / hybrid).
    return(structure(
      list(temporal        = .ido_wrap(t(temp), method = "relative",
                                       directed = TRUE),
           contemporaneous = .ido_wrap(t(cont),
                                       method = if (cov_mode) "co_occurrence"
                                                else "relative",
                                       directed = !cov_mode)),
      class = "netobject_group"))
  }

  node_labels <- c(paste0(vars, "_lag"), vars)
  A <- matrix(0, 2L * p, 2L * p, dimnames = list(node_labels, node_labels))
  A[seq_len(p),        (p + 1L):(2L * p)] <- t(temp)   # V_i_lag -> V_j (incl. AR)
  A[(p + 1L):(2L * p), (p + 1L):(2L * p)] <- t(cont)   # V_i -> V_j (contemporaneous)

  .ido_wrap(A, method = "relative", directed = TRUE)
}

#' GIMME matrices in plotting orientation (from/source in rows, to/target in cols)
#' @keywords internal
#' @noRd
.gimme_layer_matrices <- function(x, weight = c("prop", "coef")) {
  weight <- match.arg(weight)
  vars <- x$labels
  n <- x$n_subjects
  cov_mode <- isTRUE(x$contemp_is_cov)
  if (weight == "prop") {
    temp <- x$path_counts[, paste0(vars, "lag"), drop = FALSE] / n
    cont <- if (cov_mode) x$contemp_cov / n else
      x$path_counts[, vars, drop = FALSE] / n
  } else {
    temp <- x$temporal_avg
    cont <- if (cov_mode) x$contemp_cov_avg else x$contemporaneous_avg
  }
  dimnames(temp) <- dimnames(cont) <- list(vars, vars)
  list(temporal = t(temp), contemporaneous = t(cont), cov_mode = cov_mode)
}

#' Build a mixed cograph_network GIMME object
#' @keywords internal
#' @noRd
.gimme_cograph_network <- function(x, weight = c("prop", "coef"),
                                   group_color = "black",
                                   individual_color = "grey60") {
  weight <- match.arg(weight)
  edf <- .gimme_mixed_edges(x, weight = weight, group_color = group_color,
                            individual_color = individual_color)
  vars <- x$labels
  nodes_df <- data.frame(
    id = seq_along(vars), label = vars, name = vars,
    x = NA_real_, y = NA_real_, stringsAsFactors = FALSE
  )
  node_id <- stats::setNames(nodes_df$id, nodes_df$label)
  cedges <- data.frame(
    from = as.integer(node_id[edf$from]),
    to = as.integer(node_id[edf$to]),
    weight = edf$weight,
    type = ifelse(edf$kind == "contemp" & isTRUE(x$contemp_is_cov),
                  "undirected", "directed"),
    kind = edf$kind,
    style = edf$style,
    color = edf$color,
    level = edf$level,
    path = edf$path,
    from_label = edf$from,
    to_label = edf$to,
    show_arrows = !(edf$kind == "contemp" & isTRUE(x$contemp_is_cov)),
    stringsAsFactors = FALSE
  )
  out <- c(
    list(
      nodes = nodes_df,
      edges = cedges,
      directed = TRUE,
      weights = NULL,
      data = edf,
      meta = list(
        source = "idiographic",
        estimator = "gimme",
        type = "mixed",
        layout = NULL,
        tna = NULL,
        weight = weight
      ),
      node_groups = NULL
    ),
    x
  )
  class(out) <- c("net_gimme", "cograph_network", "list")
  out
}

#' Build the GIMME mixed-network edge list (gimme plotting semantics)
#'
#' One row per estimated path across both lag-1 (temporal) and lag-0
#' (contemporaneous) effects, on the `p` variables themselves. Lagged paths
#' (including autoregression, which becomes a self-loop) carry `style = "dashed"`;
#' contemporaneous paths `style = "solid"`. `color` marks group-level paths
#' (those in `x$group_paths`) versus individual-level. `weight` is the proportion
#' of subjects with the path (`"prop"`) or the group-average coefficient
#' (`"coef"`). Lagged and contemporaneous effects between the same pair become
#' two parallel edges, exactly as in the `gimme` package.
#' @keywords internal
#' @noRd
.gimme_mixed_edges <- function(x, weight = c("prop", "coef"),
                               group_color = "black",
                               individual_color = "grey60") {
  weight <- match.arg(weight)
  vars <- x$labels; n <- x$n_subjects; pc <- x$path_counts

  block <- function(predictor_cols, coef_mat, kind, drop_self) {
    g <- expand.grid(to = vars, from = vars, stringsAsFactors = FALSE)
    if (drop_self) g <- g[g$to != g$from, , drop = FALSE]
    g$count <- pc[cbind(g$to, predictor_cols(g$from))]
    g$coef  <- coef_mat[cbind(g$to, g$from)]
    g$kind  <- kind
    g$path  <- paste0(g$to, "~", predictor_cols(g$from))
    g
  }
  lagged  <- block(function(v) paste0(v, "lag"), x$temporal_avg,
                   "lagged",  drop_self = FALSE)
  if (isTRUE(x$contemp_is_cov)) {
    # VAR / hybrid: contemporaneous is an undirected residual-covariance network
    # ($contemp_cov / $contemp_cov_avg), so emit each pair once (~~), counts and
    # coefs from the covariance matrices rather than the all-zero directed block.
    cc <- x$contemp_cov; ca <- x$contemp_cov_avg
    g <- expand.grid(to = vars, from = vars, stringsAsFactors = FALSE)
    g <- g[as.character(g$from) < as.character(g$to), , drop = FALSE]
    g$count <- cc[cbind(g$to, g$from)]
    g$coef  <- ca[cbind(g$to, g$from)]
    g$kind  <- "contemp"
    g$path  <- paste0(g$to, "~~", g$from)
    contemp <- g
  } else {
    contemp <- block(function(v) v,              x$contemporaneous_avg,
                     "contemp", drop_self = TRUE)
  }

  all <- rbind(lagged, contemp)
  all <- all[all$count > 0, , drop = FALSE]
  # A zero-edge fit (e.g. ar = FALSE with no group/individual paths selected) is
  # a legitimate result, so return an empty edge list here rather than erroring:
  # build_gimme() must still return its (all-zero) matrices, and it is the
  # plotting layer -- not estimation -- that special-cases the empty graph.
  # Group-level (black) = paths in the group model: the group-search additions
  # (`group_paths`) PLUS the fixed paths every subject carries (autoregression
  # and any user-forced `paths`). Everything else is individual-level (grey).
  # This matches gimme, where AR/fixed paths are group-level.
  group_set <- unique(c(x$group_paths, x$config$fixed_paths))
  # Covariance paths (`a~~b`) are symmetric, so match group membership with the
  # two sides sorted -- otherwise `B~~A` stored in group_paths would miss `A~~B`.
  canon <- function(p) {
    sym <- grepl("~~", p, fixed = TRUE)
    p[sym] <- vapply(strsplit(p[sym], "~~", fixed = TRUE), function(s) {
      s <- sort(trimws(s)); paste0(s[1L], "~~", s[2L])
    }, character(1))
    p
  }
  in_group <- canon(all$path) %in% canon(group_set)
  data.frame(
    from   = all$from,
    to     = all$to,
    weight = if (weight == "prop") all$count / n else all$coef,
    style  = ifelse(all$kind == "lagged", "dashed", "solid"),
    color  = ifelse(in_group, group_color, individual_color),
    kind   = all$kind,
    path   = all$path,
    level  = ifelse(in_group, "group", "individual"),
    stringsAsFactors = FALSE
  )
}

#' Faithful GIMME network plot (the `gimme`-package convention, via cograph)
#'
#' Draws a GIMME result the way the `gimme` package does: a single `p`-node
#' network where \strong{dashed edges are lag-1 (temporal)} and \strong{solid
#' edges are lag-0 (contemporaneous)}, \strong{edge width is the proportion of
#' subjects} that have the path, \strong{black edges are group-level} paths and
#' grey edges individual-level, and autoregression shows as a dashed self-loop.
#' Rendered with [cograph::splot()], so a lag and a contemporaneous effect
#' between the same pair are drawn as two parallel edges.
#'
#' @param x A `net_gimme` object from [build_gimme()].
#' @param weight `"prop"` (default, proportion of subjects) or `"coef"`
#'   (group-average standardized coefficient) for edge width.
#' @param group_color,individual_color Edge colours for group- vs
#'   individual-level paths. Defaults `"black"` / `"grey60"`.
#' @param layout cograph layout passed to [cograph::splot()]. Default
#'   `"circle"`, matching gimme.
#' @param curvature Edge curvature (separates parallel lag/contemp edges).
#'   Default `0.25`.
#' @param edge_scale Multiplier mapping weight to drawn line width. Default `5`.
#' @param ... Further arguments forwarded to [cograph::splot()].
#' @return Invisibly, the mixed `cograph_network` object that was plotted.
#' @seealso [as_netobject()] for the matrix view.
#' @examplesIf requireNamespace("lavaan", quietly = TRUE) && requireNamespace("cograph", quietly = TRUE)
#' \donttest{
#' set.seed(1)
#' panel <- data.frame(
#'   id = rep(1:5, each = 30),
#'   t  = rep(seq_len(30), 5),
#'   A  = rnorm(150), B = rnorm(150), C = rnorm(150)
#' )
#' gm <- build_gimme(panel, vars = c("A", "B", "C"), id = "id", time = "t")
#' plot_gimme(gm)
#' }
#' @export
plot_gimme <- function(x, weight = c("prop", "coef"),
                       group_color = "black", individual_color = "grey60",
                       layout = "circle", curvature = 0.25, edge_scale = 5,
                       ...) {
  if (!inherits(x, "net_gimme")) {
    stop("plot_gimme() needs a 'net_gimme' object from build_gimme().",
         call. = FALSE)
  }
  .ido_require_cograph("plot_gimme")
  weight <- match.arg(weight)
  net <- if (identical(weight, x$meta$weight %||% "prop") &&
             identical(group_color, "black") &&
             identical(individual_color, "grey60") &&
             inherits(x, "cograph_network")) {
    x
  } else {
    .gimme_cograph_network(x, weight = weight, group_color = group_color,
                           individual_color = individual_color)
  }
  edf <- net$edges
  if (is.null(edf) || nrow(edf) == 0L) {
    # Zero-edge fit: draw the nodes only rather than passing empty per-edge
    # styling vectors to cograph (the estimation step no longer errors here).
    message("GIMME model has no estimated paths; drawing nodes only.")
    cograph::splot(net, layout = layout, directed = TRUE, ...)
    return(invisible(net))
  }
  cograph::splot(net, layout = layout, directed = TRUE,
                 edge_style = edf$style, edge_color = edf$color,
                 edge_width = abs(edf$weight) * edge_scale,
                 curvature = curvature, show_arrows = edf$show_arrows, ...)
  invisible(net)
}

#' Tidy edge table from a network object
#'
#' Returns a one-row-per-edge `data.frame` with node labels, for any
#' netobject / cograph_network (or a `gvar_result` constituent).
#'
#' @param model A `netobject` or `cograph_network`. Multi-network results
#'   (a `gvar_result`, `net_mlvar`, or any `netobject_group`) hold more than one
#'   network, so pass a single constituent — e.g.
#'   `extract_edges(as_netobject(x)$temporal)`.
#' @param sort_by Either `"weight"` (descending by absolute weight) or `NULL`.
#' @param include_self Keep autoregressive self-loops? Default `FALSE`.
#' @return A `data.frame` with columns `from`, `to`, `weight`.
#' @export
extract_edges <- function(model, sort_by = "weight", include_self = FALSE) {
  if (inherits(model, "netobject_group") ||
      inherits(model, "gvar_result") || inherits(model, "net_mlvar")) {
    stop("extract_edges() received a multi-network result; it works on a ",
         "single network. Use extract_edges(as_netobject(x)$temporal), ",
         "...$contemporaneous, or ...$between (mlVAR).", call. = FALSE)
  }
  net <- as_netobject(model)
  m <- net$weights
  directed <- net$directed %||% TRUE
  labs <- net$nodes$label %||% as.character(seq_len(nrow(m)))
  idx <- .net_edge_idx(m, directed, include_self = include_self)
  if (nrow(idx) == 0L) {
    return(data.frame(from = character(), to = character(),
                      weight = numeric(), stringsAsFactors = FALSE))
  }
  out <- data.frame(from = labs[idx[, 1]], to = labs[idx[, 2]],
                    weight = m[idx], stringsAsFactors = FALSE)
  if (identical(sort_by, "weight")) out <- out[order(-abs(out$weight)), ]
  rownames(out) <- NULL
  out
}


# ============================================================================
# Tidy output layer
#
# One verb, one tidy data.frame. `edges()` turns ANY idiographic result -- a single
# network, a multi-network group, or a fitted estimator -- into a single
# one-row-per-edge data.frame with a `network` column, so you print it directly
# instead of digging into matrices. `as.data.frame()` delegates to it.
# Orientation is always from = predictor/source, to = outcome/target.
# ============================================================================

#' Tidy edge table for any idiographic result
#'
#' A single tidy verb for every network idiographic produces. Returns one row per
#' edge with columns `network` (e.g. `"temporal"`, `"contemporaneous"`,
#' `"between"`), `from`, `to`, `weight` -- and, for GIMME, `level`
#' (`"group"`/`"individual"`). Directed networks (temporal) keep every edge;
#' undirected networks (contemporaneous, between) report each pair once.
#'
#' @param x A `gvar_result`, `net_mlvar`, `net_gimme`, `netobject`, or
#'   `netobject_group`.
#' @param sort_by `"weight"` (descending |weight|) or `NULL` for natural order.
#' @param include_self Keep autoregressive self-loops? Default `FALSE`
#'   (`TRUE` for GIMME, where the autoregression is the point).
#' @param ... Passed to methods.
#' @return A tidy `data.frame`, one row per edge.
#' @examplesIf requireNamespace("graphicalVAR", quietly = TRUE)
#' \donttest{
#' set.seed(1)
#' d <- data.frame(id = 1, A = rnorm(80), B = rnorm(80), C = rnorm(80))
#' fit <- graphical_var(d, vars = c("A", "B", "C"), id = "id", n_lambda = 8)
#' edges(fit)            # tidy: network / from / to / weight
#' }
#' @export
edges <- function(x, ...) UseMethod("edges")

#' @rdname edges
#' @export
edges.netobject <- function(x, sort_by = "weight", include_self = FALSE, ...) {
  e <- extract_edges(x, sort_by = sort_by, include_self = include_self)
  net <- x$meta$tna$method %||% x$method %||% "network"
  data.frame(network = rep(net, nrow(e)), e, stringsAsFactors = FALSE)
}

#' @rdname edges
#' @export
edges.netobject_group <- function(x, sort_by = "weight",
                                  include_self = FALSE, ...) {
  nms <- names(x)
  if (is.null(nms)) nms <- paste0("network", seq_along(x))
  parts <- lapply(seq_along(x), function(i) {
    e <- extract_edges(x[[i]], sort_by = sort_by, include_self = include_self)
    if (nrow(e) == 0L) return(NULL)
    data.frame(network = rep(nms[i], nrow(e)), e, stringsAsFactors = FALSE)
  })
  parts <- parts[!vapply(parts, is.null, logical(1))]
  out <- if (length(parts) == 0L) {
    data.frame(network = character(), from = character(), to = character(),
               weight = numeric(), stringsAsFactors = FALSE)
  } else {
    do.call(rbind, parts)
  }
  rownames(out) <- NULL
  out
}

#' @rdname edges
#' @export
edges.gvar_result <- function(x, sort_by = "weight", include_self = FALSE, ...) {
  edges(as_netobject(x), sort_by = sort_by, include_self = include_self)
}

#' @rdname edges
#' @export
edges.net_mlvar <- function(x, sort_by = "weight", include_self = FALSE, ...) {
  # as_netobject() reorients temporal to from = predictor, to = outcome.
  edges(as_netobject(x), sort_by = sort_by, include_self = include_self)
}

#' @rdname edges
#' @param weight For GIMME only: `"prop"` (proportion of subjects, default) or
#'   `"coef"` (group-average coefficient) for the edge weight.
#' @export
edges.net_gimme <- function(x, sort_by = "weight", include_self = TRUE,
                            weight = c("prop", "coef"), ...) {
  e <- .gimme_mixed_edges(x, weight = match.arg(weight))
  if (!include_self) e <- e[e$from != e$to, , drop = FALSE]
  out <- data.frame(
    network = ifelse(e$kind == "lagged", "temporal", "contemporaneous"),
    from = e$from, to = e$to, weight = e$weight, level = e$level,
    stringsAsFactors = FALSE
  )
  if (identical(sort_by, "weight")) out <- out[order(-abs(out$weight)), ]
  rownames(out) <- NULL
  out
}

#' @export
as.data.frame.gvar_result <- function(x, row.names = NULL, optional = FALSE,
                                      ...) {
  edges(x, ...)
}

#' @export
as.data.frame.net_mlvar <- function(x, row.names = NULL, optional = FALSE, ...) {
  edges(x, ...)
}

#' @export
as.data.frame.net_gimme <- function(x, row.names = NULL, optional = FALSE, ...) {
  edges(x, ...)
}

#' @export
as.data.frame.netobject <- function(x, row.names = NULL, optional = FALSE, ...) {
  edges(x, ...)
}

#' @export
as.data.frame.netobject_group <- function(x, row.names = NULL,
                                          optional = FALSE, ...) {
  edges(x, ...)
}


# ---- shared tidy helpers ---------------------------------------------------

#' Long-form (network, from, to, weight) table of a netobject's weight matrix.
#' `keep_zeros = TRUE` includes every pair (the full coefficient table); FALSE
#' only the realised edges. Orientation is from = row, to = col (predictor ->
#' outcome, as the constructor builds it).
#' @noRd
.tidy_net_long <- function(net, network, keep_zeros = FALSE) {
  W <- net$weights
  labs <- net$nodes$label %||% rownames(W) %||% as.character(seq_len(nrow(W)))
  directed <- isTRUE(net$directed)
  # Directed coefficient tables keep the AR diagonal; undirected ones list each
  # pair once without the self-variance diagonal -- i.e. include_self = directed.
  sel <- .net_edge_idx(W, directed, include_self = directed,
                       keep_zeros = keep_zeros)
  if (nrow(sel) == 0L) {
    return(data.frame(network = character(), from = character(),
                      to = character(), weight = numeric(),
                      stringsAsFactors = FALSE))
  }
  data.frame(network = rep(network, nrow(sel)),
             from = labs[sel[, 1]], to = labs[sel[, 2]], weight = W[sel],
             stringsAsFactors = FALSE)
}

#' One-row network metrics for a netobject.
#' @noRd
.net_metrics <- function(net, network) {
  W <- net$weights
  directed <- isTRUE(net$directed)
  n <- nrow(W)
  # Same edge rule as edges()/coefs() (self-loops excluded for metrics).
  idx <- .net_edge_idx(W, directed, include_self = FALSE)
  w <- W[idx]
  n_edges <- length(w)
  n_poss  <- if (directed) n * (n - 1) else n * (n - 1) / 2
  data.frame(
    network         = network,
    n_nodes         = n,
    n_edges         = n_edges,
    density         = if (n_poss > 0) n_edges / n_poss else 0,
    mean_abs_weight = if (length(w)) mean(abs(w)) else 0,
    n_positive      = sum(w > 0),
    n_negative      = sum(w < 0),
    stringsAsFactors = FALSE
  )
}

#' Per-node strength table for a netobject.
#'
#' `strength` excludes self-loops (network-analysis convention), but the
#' autoregressive / self-loop weight is reported separately in `self` so it is
#' not silently lost -- `edges()` keeps GIMME's AR self-loops, and this column
#' lets `nodes()` reconcile with them instead of reporting 0 for an AR-only node.
#' @noRd
.net_nodes <- function(net, network) {
  W <- net$weights
  directed <- isTRUE(net$directed)
  labs <- net$nodes$label %||% rownames(W) %||% as.character(seq_len(nrow(W)))
  self <- as.numeric(diag(W))                    # autoregression / self-loop
  A <- abs(W); diag(A) <- 0
  if (directed) {
    out_s <- rowSums(A); in_s <- colSums(A)
    data.frame(network = network, node = labs, strength = out_s + in_s,
               out_strength = out_s, in_strength = in_s, self = self,
               stringsAsFactors = FALSE)
  } else {
    s <- rowSums(A)
    data.frame(network = network, node = labs, strength = s,
               out_strength = NA_real_, in_strength = NA_real_, self = self,
               stringsAsFactors = FALSE)
  }
}

#' Map a tidy per-network helper over a result, returning one stacked data.frame.
#' @noRd
.tidy_over_group <- function(group, fun) {
  nms <- names(group)
  if (is.null(nms)) nms <- paste0("network", seq_along(group))
  out <- do.call(rbind, lapply(seq_along(group),
                               function(i) fun(group[[i]], nms[i])))
  rownames(out) <- NULL
  out
}


# ---- coefs(): tidy coefficient estimates -----------------------------------

#' @rdname coefs
#' @export
coefs.gvar_result <- function(x, ...) {
  # Full coefficient table (every pair, including zeros) for the temporal and
  # contemporaneous networks of one subject.
  g <- as_netobject(x)
  .tidy_over_group(g, function(net, nm) .tidy_net_long(net, nm,
                                                       keep_zeros = TRUE))
}

#' @rdname coefs
#' @export
coefs.net_gimme <- function(x, ...) {
  # Per-person estimated paths: one row per (subject, network, from, to).
  vars <- x$labels
  lag_names <- paste0(vars, "lag")
  rows <- lapply(names(x$coefs), function(s) {
    M <- x$coefs[[s]]
    tl <- M[, lag_names, drop = FALSE]            # temporal (lagged)
    cl <- M[, vars, drop = FALSE]                 # contemporaneous
    # NA-safe (a non-converged subject's matrix may hold NA): treat NA as "no
    # edge" explicitly, matching the path_counts guard in .gimme_extract_results.
    ti <- which(!is.na(tl) & tl != 0, arr.ind = TRUE)
    ci <- which(!is.na(cl) & cl != 0, arr.ind = TRUE)
    parts <- list()
    if (nrow(ti) > 0L) parts$t <- data.frame(
      subject = s, network = "temporal",
      from = vars[ti[, 2]], to = rownames(M)[ti[, 1]], weight = tl[ti],
      stringsAsFactors = FALSE)
    if (nrow(ci) > 0L) parts$c <- data.frame(
      subject = s, network = "contemporaneous",
      from = vars[ci[, 2]], to = rownames(M)[ci[, 1]], weight = cl[ci],
      stringsAsFactors = FALSE)
    if (length(parts)) do.call(rbind, parts) else NULL
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  out <- if (length(rows)) do.call(rbind, rows) else data.frame(
    subject = character(), network = character(), from = character(),
    to = character(), weight = numeric(), stringsAsFactors = FALSE)
  rownames(out) <- NULL
  out
}


# ---- nodes(): tidy per-node strength ---------------------------------------

#' Tidy per-node strength table for any idiographic result
#'
#' One row per node per network with `strength` (sum of absolute incident edge
#' weights) and, for directed networks, `out_strength` / `in_strength`
#' (`NA` for undirected). Self-loops are excluded.
#'
#' @param x A `gvar_result`, `net_mlvar`, `net_gimme`, `netobject`, or
#'   `netobject_group`.
#' @param ... Passed to methods.
#' @return A tidy `data.frame`.
#' @export
nodes <- function(x, ...) UseMethod("nodes")

#' @rdname nodes
#' @export
nodes.netobject <- function(x, ...) .net_nodes(x, x$method %||% "network")

#' @rdname nodes
#' @export
nodes.netobject_group <- function(x, ...) .tidy_over_group(x, .net_nodes)

#' @rdname nodes
#' @export
nodes.gvar_result <- function(x, ...) nodes(as_netobject(x), ...)

#' @rdname nodes
#' @export
nodes.net_mlvar <- function(x, ...) nodes(as_netobject(x), ...)

#' @rdname nodes
#' @export
nodes.net_gimme <- function(x, ...) nodes(as_netobject(x), ...)


# ---- matrices(): compact matrix inspection ---------------------------------

#' Print model matrices for idiographic results
#'
#' `matrices()` is the matrix-oriented companion to [summary()] and [edges()].
#' It returns the core estimated matrices invisibly and prints each matrix
#' compactly with rounding, so users can inspect coefficients without digging
#' through object internals.
#'
#' @param x An idiographic result or cograph network/group.
#' @param digits Number of digits used for printing. Default `3`.
#' @param fit Stored fit name or index for result containers that optionally keep
#'   fitted models, such as rolling results and model comparisons.
#' @param ... Passed to methods.
#' @return Invisibly, a named list of matrices.
#' @export
matrices <- function(x, ...) UseMethod("matrices")

#' @rdname matrices
#' @export
matrices.default <- function(x, digits = 3, ...) {
  stop("No matrices() method for <",
       paste(class(x), collapse = "/"), ">.", call. = FALSE)
}

#' @rdname matrices
#' @export
matrices.cograph_network <- function(x, digits = 3, ...) {
  out <- if (!is.null(x$weights) && is.matrix(x$weights)) {
    list(weights = x$weights)
  } else {
    list()
  }
  .ido_print_matrices(out, digits = digits)
}

#' @rdname matrices
#' @export
matrices.netobject <- function(x, digits = 3, ...) {
  matrices.cograph_network(x, digits = digits, ...)
}

#' @rdname matrices
#' @export
matrices.netobject_group <- function(x, digits = 3, ...) {
  out <- lapply(unclass(x), function(net) {
    if (!is.null(net$weights) && is.matrix(net$weights)) net$weights else NULL
  })
  out <- out[!vapply(out, is.null, logical(1))]
  .ido_print_matrices(out, digits = digits)
}

#' @rdname matrices
#' @export
matrices.gvar_result <- function(x, digits = 3, ...) {
  .ido_print_matrices(list(
    beta = x$beta,
    temporal = x$temporal,
    kappa = x$kappa,
    PCC = x$PCC,
    PDC = x$PDC
  ), digits = digits)
}

#' @rdname matrices
#' @export
matrices.var_result <- function(x, digits = 3, ...) {
  .ido_print_matrices(list(
    beta = x$beta,
    temporal = x$temporal,
    residual_cov = x$residual_cov,
    kappa = x$kappa,
    PCC = x$PCC,
    PDC = x$PDC
  ), digits = digits)
}

#' @rdname matrices
#' @export
matrices.net_mlvar <- function(x, digits = 3, ...) {
  .ido_print_matrices(list(
    temporal = x$temporal$weights,
    contemporaneous = x$contemporaneous$weights,
    between = x$between$weights
  ), digits = digits)
}

#' @rdname matrices
#' @export
matrices.net_usem <- function(x, digits = 3, ...) {
  .ido_print_matrices(list(
    temporal = x$temporal,
    contemporaneous = x$contemporaneous,
    residual_cov = x$residual_cov
  ), digits = digits)
}

#' @rdname matrices
#' @export
matrices.net_gimme <- function(x, digits = 3, ...) {
  mats <- list(
    temporal_counts = x$temporal,
    temporal_avg = x$temporal_avg,
    contemporaneous_counts = x$contemporaneous,
    contemporaneous_avg = x$contemporaneous_avg,
    path_counts = x$path_counts
  )
  if (!is.null(x$contemp_cov)) mats$contemp_cov <- x$contemp_cov
  if (!is.null(x$contemp_cov_avg)) mats$contemp_cov_avg <- x$contemp_cov_avg
  .ido_print_matrices(mats, digits = digits)
}

#' @rdname matrices
#' @export
matrices.preprocess_audit <- function(x, digits = 3, ...) {
  .ido_print_matrices(x$matrices, digits = digits)
}

#' @rdname matrices
#' @export
matrices.rolling_var_result <- function(x, fit = 1L, digits = 3, ...) {
  matrices(.ido_pick_fit(x$fits, fit, "fit"), digits = digits, ...)
}

#' @rdname matrices
#' @export
matrices.rolling_gvar_result <- function(x, fit = 1L, digits = 3, ...) {
  matrices(.ido_pick_fit(x$fits, fit, "fit"), digits = digits, ...)
}

#' @rdname matrices
#' @export
matrices.stability_result <- function(x, digits = 3, ...) {
  matrices(x$original, digits = digits, ...)
}

#' @rdname matrices
#' @export
matrices.model_comparison <- function(x, fit = 1L, digits = 3, ...) {
  matrices(.ido_pick_fit(x$fits, fit, "fit"), digits = digits, ...)
}

#' @keywords internal
#' @noRd
.ido_pick_fit <- function(fits, fit, arg) {
  if (is.null(fits) || length(fits) == 0L) {
    stop("No fitted models are stored. Rerun with `keep_fits = TRUE`.",
         call. = FALSE)
  }
  if (is.character(fit) && length(fit) == 1L) {
    if (!fit %in% names(fits)) {
      stop("Unknown ", arg, " '", fit, "'. Available values: ",
           paste(names(fits), collapse = ", "), call. = FALSE)
    }
    return(fits[[fit]])
  }
  if (is.numeric(fit) && length(fit) == 1L && is.finite(fit) &&
      fit == as.integer(fit) && fit >= 1L && fit <= length(fits)) {
    return(fits[[as.integer(fit)]])
  }
  stop("`", arg, "` must be a stored fit name or index.", call. = FALSE)
}

#' Print one network block Nestimate-style: a one-line weight summary followed
#' by the labelled, rounded weight matrix. `directed` controls which cells count
#' as edges for the summary (all non-zero for directed, upper triangle for
#' undirected) and how the block is tagged.
#' @keywords internal
#' @noRd
.ido_print_net_block <- function(mat, title, directed, digits = 2) {
  finite_nz <- if (directed) {
    mat[is.finite(mat) & mat != 0]
  } else {
    sel <- row(mat) < col(mat) & is.finite(mat) & mat != 0
    mat[sel]
  }
  cat(sprintf("\n  %s [%s]\n", title, if (directed) "directed" else "undirected"))
  if (length(finite_nz) > 0L) {
    cat(sprintf("    weights [%.3f, %.3f]  |  +%d / -%d edges\n",
                min(finite_nz), max(finite_nz),
                sum(finite_nz > 0), sum(finite_nz < 0)))
  } else {
    cat("    no non-zero edges\n")
  }
  formatted <- utils::capture.output(print(round(mat, digits)))
  cat(paste0("    ", formatted, collapse = "\n"), "\n", sep = "")
  invisible(NULL)
}

#' Print every network of a result the way it is plotted/returned by edges():
#' delegates to as_netobject() so orientation (rows = from/predictor) and
#' directedness always match plot() and edges(). Title-cases the layer names.
#' @keywords internal
#' @noRd
.ido_print_networks <- function(x, digits = 2) {
  g <- as_netobject(x)
  nms <- names(g)
  if (is.null(nms)) nms <- paste0("network", seq_along(g))
  pretty <- vapply(nms, function(s)
    paste0(toupper(substring(s, 1, 1)), substring(s, 2)), character(1))
  for (i in seq_along(g)) {
    net <- g[[i]]
    .ido_print_net_block(net$weights, pretty[i], isTRUE(net$directed), digits)
  }
  invisible(NULL)
}

#' @keywords internal
#' @noRd
.ido_print_matrices <- function(x, digits = 3) {
  if (length(x) == 0L) {
    cat("No matrix payload available.\n")
    return(invisible(x))
  }
  for (nm in names(x)) {
    cat("\n$", nm, "\n", sep = "")
    print(round(x[[nm]], digits))
  }
  invisible(x)
}
