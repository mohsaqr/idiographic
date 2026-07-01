# Pure-R graphical lasso (Friedman, Hastie & Tibshirani 2008, Biostatistics).
#
# Replaces glasso::glasso() and glasso::glassopath() so idiographic's regularised
# (EBICglasso) network estimation carries no compiled dependency. The graphical
# lasso objective
#     min_{Theta > 0}  -log det Theta + tr(S Theta) + rho * sum_{i != j}|Theta_ij|
# is strictly convex in Theta, so its minimiser is unique. A tightly converged
# pure-R fit therefore returns the same global optimum as glasso's Fortran
# kernel (agreement ~1e-11) and satisfies the stationarity (KKT) conditions to
# the same order (see .glasso_kkt_violation()). Validated against glasso over
# 200+ random configurations and 100 Saqrlab datasets in
# local_testing_and_equivalence/ (median KKT violation ~1e-12).
#
# The covariance (W) block-coordinate descent: for each column the off-diagonal
# update is an ordinary lasso solved by Gauss-Seidel soft-thresholding, and the
# precision matrix is reconstructed from the converged W and the lasso
# coefficients. The outer column sweep and the inner coordinate descent are
# Gauss-Seidel -- each update consumes the latest values -- so these loops are a
# genuine sequential dependency, not a vectorisation that was skipped (the inner
# dot products ARE vectorised). This is the same documented exception to the
# no-loops rule as the sequence_compare() permutation loop.

# --- soft-threshold operator -------------------------------------------------
.soft <- function(z, g) sign(z) * pmax(abs(z) - g, 0)

# --- single lasso solve for one column (Gauss-Seidel coordinate descent) ------
# `rho` is the per-coordinate L1 penalty (length pp), so element-wise penalty
# matrices (glasso's `rho` matrix / graphicalVAR's regularize_mat) are supported.
# `free` (optional logical, length pp) marks coordinates that may move; entries
# with free == FALSE are held at their incoming value (used by the zero-edge
# constraint of the refit path). NULL means all coordinates are free.
.glasso_lasso_column <- function(W11, s12, beta, rho, max_inner, tol_inner,
                                 free = NULL) {
  pp <- length(s12)
  ks <- if (is.null(free)) seq_len(pp) else which(free)
  for (inner in seq_len(max_inner)) {
    max_diff <- 0
    for (k in ks) {
      # partial = s12[k] - sum_{l != k} W11[k, l] * beta[l]
      partial <- s12[k] - (sum(W11[k, ] * beta) - W11[k, k] * beta[k])
      wkk <- W11[k, k]
      new_k <- if (wkk < 1e-12) 0 else .soft(partial, rho[k]) / wkk
      d <- abs(new_k - beta[k])
      if (d > max_diff) max_diff <- d
      beta[k] <- new_k
    }
    if (max_diff < tol_inner) break
  }
  beta
}

#' Single graphical-lasso fit at a fixed penalty (pure R)
#'
#' Drop-in replacement for \code{glasso::glasso(s = S, rho, penalize.diagonal,
#' start, w.init, wi.init, zero)}: returns the same \code{$wi} (precision) and
#' \code{$w} (regularised covariance) to ~1e-11.
#'
#' @param S Covariance / correlation matrix (p x p, symmetric).
#' @param rho Scalar L1 penalty.
#' @param penalize.diagonal Logical; if TRUE the diagonal of Theta is also
#'   penalised (working covariance diagonal becomes \code{diag(S) + rho}).
#'   Default FALSE, matching qgraph::EBICglasso and every Nestimate call site.
#' @param max_outer,tol_outer Outer (column-sweep) convergence control.
#' @param max_inner,tol_inner Inner (coordinate-descent) convergence control.
#' @param w_init,beta_init Optional warm starts (covariance estimate and lasso
#'   coefficient matrix from a previous fit).
#' @param zero Optional 2-column matrix of (row, col) index pairs whose Theta
#'   entries are hard-constrained to zero (matches glasso's \code{zero=} for the
#'   unpenalised refit). The diagonal is never constrained.
#' @return list(wi = precision matrix, w = covariance estimate, beta = lasso
#'   coefficient matrix).
#' @noRd
.glasso_fit <- function(S, rho,
                        penalize.diagonal = FALSE,
                        max_outer = 1e4, tol_outer = 1e-8,
                        max_inner = 1e4, tol_inner = 1e-10,
                        w_init = NULL, beta_init = NULL, zero = NULL) {
  if (!is.matrix(S) || !is.numeric(S) || nrow(S) != ncol(S)) {
    stop(".glasso_fit(): 'S' must be a square numeric matrix.", call. = FALSE)
  }
  if (any(!is.finite(S))) {
    stop(".glasso_fit(): 'S' contains non-finite values.", call. = FALSE)
  }
  if (max(abs(S - t(S))) > 1e-8) {
    stop(".glasso_fit(): 'S' must be symmetric.", call. = FALSE)
  }
  p <- ncol(S)
  # rho may be a single non-negative number OR a p x p non-negative penalty
  # matrix (element-wise L1 penalties, matching glasso's matrix `rho` and
  # graphicalVAR's regularize_mat). Normalise to a matrix `Rho`.
  if (is.matrix(rho)) {
    if (nrow(rho) != p || ncol(rho) != p || any(!is.finite(rho)) ||
        any(rho < 0)) {
      stop(".glasso_fit(): matrix 'rho' must be p x p, finite, non-negative.",
           call. = FALSE)
    }
    Rho <- rho
  } else {
    if (!(is.numeric(rho) && length(rho) == 1L && is.finite(rho) && rho >= 0)) {
      stop(".glasso_fit(): 'rho' must be a single non-negative number or a ",
           "p x p matrix.", call. = FALSE)
    }
    Rho <- matrix(rho, p, p)
  }
  W <- if (is.null(w_init)) S else w_init
  diag(W) <- if (isTRUE(penalize.diagonal)) diag(S) + diag(Rho) else diag(S)
  Beta <- if (is.null(beta_init)) matrix(0, p, p) else beta_init

  # Symmetric logical mask of constrained (zeroed) off-diagonal entries.
  zmask <- NULL
  if (!is.null(zero) && nrow(zero) > 0L) {
    zmask <- matrix(FALSE, p, p)
    zmask[zero] <- TRUE
    zmask[zero[, c(2L, 1L), drop = FALSE]] <- TRUE
    diag(zmask) <- FALSE
  }

  for (outer in seq_len(max_outer)) {
    max_diff <- 0
    for (j in seq_len(p)) {
      idx  <- seq_len(p)[-j]
      W11  <- W[idx, idx, drop = FALSE]
      s12  <- S[idx, j]
      bcol <- Beta[j, idx]
      free <- NULL
      if (!is.null(zmask)) {
        constrained <- zmask[idx, j]
        bcol[constrained] <- 0          # force zeroed edges to exactly 0
        free <- !constrained
      }
      beta <- .glasso_lasso_column(W11, s12, bcol, Rho[idx, j], max_inner,
                                   tol_inner, free)
      w12  <- as.numeric(W11 %*% beta)

      d <- max(abs(w12 - W[idx, j]))
      if (d > max_diff) max_diff <- d
      W[idx, j] <- w12
      W[j, idx] <- w12
      Beta[j, idx] <- beta
    }
    if (max_diff < tol_outer) break
  }

  # --- reconstruct precision matrix from converged W and Beta -----------------
  Theta <- matrix(0, p, p)
  for (j in seq_len(p)) {
    idx  <- seq_len(p)[-j]
    beta <- Beta[j, idx]
    denom <- W[j, j] - sum(W[idx, j] * beta)
    # denom is the conditional variance of column j; it is > 0 at any feasible
    # (positive-definite) W. A near-zero denom means the working covariance has
    # collapsed numerically, so cap the precision diagonal at a large finite
    # value (1e6) rather than emit Inf/NaN that would propagate into cov2cor().
    tjj <- if (abs(denom) > 1e-12) 1 / denom else 1e6
    Theta[j, j]   <- tjj
    Theta[idx, j] <- -beta * tjj
  }
  Theta <- (Theta + t(Theta)) / 2                   # symmetrise residual drift

  dimnames(Theta) <- dimnames(W) <- dimnames(S)
  list(wi = Theta, w = W, beta = Beta)
}

#' Graphical-lasso solution path over a list of penalties (pure R)
#'
#' Drop-in replacement for \code{glasso::glassopath(s = S, rholist,
#' penalize.diagonal)}: returns \code{$wi} and \code{$w} as p x p x length(rholist)
#' arrays indexed in input order, so existing consumers (\code{gp$wi[, , k]})
#' work unchanged. Each penalty is warm-started from the previous fit.
#'
#' @inheritParams .glasso_fit
#' @param rholist Vector of penalties.
#' @return list(w = 3D covariance array, wi = 3D precision array, rholist).
#'
#' Tolerance defaults match glasso::glassopath's own \code{thr = 1e-4}: the
#' bootstrap / permutation resampling paths that consume this never needed
#' machine precision (glasso did not give it to them either), and the looser
#' tolerance keeps thousands of refits tractable in pure R.
#' @noRd
.glassopath_fit <- function(S, rholist,
                            penalize.diagonal = FALSE,
                            max_outer = 1e4, tol_outer = 1e-4,
                            max_inner = 1e4, tol_inner = 1e-4) {
  p  <- ncol(S)
  nr <- length(rholist)
  dn <- list(rownames(S), colnames(S), NULL)
  wi_arr <- array(0, dim = c(p, p, nr), dimnames = dn)
  w_arr  <- array(0, dim = c(p, p, nr), dimnames = dn)

  w_prev <- NULL
  beta_prev <- NULL
  for (k in seq_len(nr)) {
    fit <- .glasso_fit(S, rholist[k], penalize.diagonal,
                       max_outer, tol_outer, max_inner, tol_inner,
                       w_init = w_prev, beta_init = beta_prev)
    wi_arr[, , k] <- fit$wi
    w_arr[, , k]  <- fit$w
    w_prev    <- fit$w
    beta_prev <- fit$beta
  }
  list(w = w_arr, wi = wi_arr, rholist = rholist)
}

#' Maximum violation of the graphical-lasso stationarity (KKT) conditions
#'
#' Independent correctness check against the estimand itself, not against any
#' reference solver. For the objective
#'   min_{Theta > 0}  -log det Theta + tr(S Theta) + rho * sum_{i != j}|Theta_ij|
#' (penalize.diagonal = FALSE), let W = Theta^{-1}. The subgradient optimality
#' conditions are:
#'   diagonal:                 W_ii = S_ii
#'   off-diagonal, Theta != 0: W_ij - S_ij = rho * sign(Theta_ij)
#'   off-diagonal, Theta == 0: |W_ij - S_ij| <= rho
#' By strict convexity, a Theta with zero violation is the unique global
#' optimum, so a near-zero return certifies correctness independently of glasso.
#'
#' @param Theta Precision matrix to test.
#' @param S Covariance / correlation the model was fit to.
#' @param rho Scalar penalty.
#' @param active_tol Magnitude above which an off-diagonal entry is "active".
#' @return Maximum absolute stationarity violation (scalar).
#' @noRd
.glasso_kkt_violation <- function(Theta, S, rho, active_tol = 1e-8) {
  W <- solve(Theta)
  diag_v <- max(abs(diag(W) - diag(S)))
  off <- upper.tri(Theta)
  r  <- (W - S)[off]
  th <- Theta[off]
  active <- abs(th) > active_tol
  v_active   <- if (any(active))  max(abs(r[active] - rho * sign(th[active]))) else 0
  v_inactive <- if (any(!active)) max(pmax(abs(r[!active]) - rho, 0)) else 0
  max(diag_v, v_active, v_inactive)
}
