# ---- Public graphical-lasso kernel (offload surface) ----
#
# `.glasso_fit()` in R/glasso_pure.R has always been idiographic's internal
# regularisation engine for fit_graphical_var(). These wrappers expose it as a
# supported public API so sibling packages can drop their own copies of the same
# pure-R kernel and depend on this one instead. The numerics are unchanged: the
# exported functions add validation, tidy accessors, and a stability contract,
# then delegate to the identical internal solver.

#' Fit a graphical lasso at a fixed penalty
#'
#' @description
#' Solves the graphical lasso problem
#' \deqn{\min_{\Theta \succ 0} \; -\log\det\Theta + \mathrm{tr}(S\Theta) +
#'       \sum_{i \neq j} \rho_{ij} |\Theta_{ij}|}
#' with a pure-R block-coordinate-descent solver (Friedman, Hastie and
#' Tibshirani, 2008). No compiled code and no external dependency is involved,
#' so the estimator is available wherever R is.
#'
#' The objective is strictly convex, so its minimiser is unique and a
#' sufficiently converged fit is *the* global optimum regardless of solver.
#' [glasso_kkt()] certifies that directly from the stationarity conditions,
#' without reference to any other implementation.
#'
#' @param S Covariance or correlation matrix (`p x p`, symmetric, finite).
#' @param rho Either a single non-negative penalty applied to every
#'   off-diagonal entry, or a `p x p` non-negative matrix of element-wise
#'   penalties.
#' @param penalize_diagonal Logical. Penalise the diagonal of `Theta` as well?
#'   Default `FALSE`, matching the usual EBIC-glasso convention.
#' @param zero Optional two-column matrix of `(row, col)` index pairs whose
#'   `Theta` entries are hard-constrained to zero. Used for the unpenalised
#'   refit of a selected edge set. The diagonal is never constrained.
#' @param max_outer,tol_outer Outer (column-sweep) iteration cap and
#'   convergence tolerance.
#' @param max_inner,tol_inner Inner (coordinate-descent) iteration cap and
#'   convergence tolerance.
#'
#' @return An object of class `glasso_result`: a list with
#'   \describe{
#'     \item{`wi`}{`p x p` estimated precision matrix \eqn{\Theta}.}
#'     \item{`w`}{`p x p` estimated (regularised) covariance \eqn{\Theta^{-1}}.}
#'     \item{`beta`}{`p x p` matrix of lasso coefficients from the column
#'       sweep, reusable as a warm start.}
#'     \item{`rho`}{The penalty as supplied -- a scalar or a `p x p` matrix.}
#'     \item{`penalize_diagonal`}{The diagonal-penalty flag used.}
#'     \item{`zero`}{The hard zero constraints applied, or `NULL`.}
#'     \item{`S`}{The covariance the fit was made to, retained so
#'       [glasso_kkt()] can certify the result on its own. For large `p` in a
#'       resampling loop this is a real retention cost; [glasso_path()] does
#'       not retain it.}
#'   }
#'   The `wi` and `w` element names are deliberately identical to those
#'   returned by `glasso::glasso()`, so existing call sites port unchanged. Use
#'   [as.data.frame()] for a tidy one-row-per-edge partial-correlation table.
#'
#' @references
#' Friedman, J., Hastie, T. and Tibshirani, R. (2008). Sparse inverse
#' covariance estimation with the graphical lasso. *Biostatistics*, 9(3),
#' 432-441. \doi{10.1093/biostatistics/kxm045}
#'
#' @seealso [glasso_path()] for a whole penalty path, [glasso_kkt()] for an
#'   optimality certificate, and [fit_graphical_var()] for the estimator that
#'   consumes this kernel.
#'
#' @examples
#' set.seed(1)
#' z <- rnorm(200)
#' x <- cbind(A = z + rnorm(200, 0, 0.5), B = z + rnorm(200, 0, 0.5),
#'            C = rnorm(200), D = rnorm(200))
#' fit <- glasso_fit(cov(x), rho = 0.05)
#' fit
#' as.data.frame(fit)
#' glasso_kkt(fit)
#' @export
glasso_fit <- function(S, rho,
                       penalize_diagonal = FALSE,
                       zero = NULL,
                       max_outer = 1e4, tol_outer = 1e-8,
                       max_inner = 1e4, tol_inner = 1e-10) {
  .ido_check_flag(penalize_diagonal, "penalize_diagonal")
  zero <- .glasso_check_zero(zero, S)
  .glasso_check_psd(S)
  fit <- .glasso_fit(
    S = S, rho = rho, penalize.diagonal = penalize_diagonal,
    max_outer = max_outer, tol_outer = tol_outer,
    max_inner = max_inner, tol_inner = tol_inner, zero = zero
  )
  # Keep `rho` exactly as supplied. Expanding a scalar to a p x p matrix here
  # would allocate a second copy of the problem for every fit, which is real
  # cost in a resampling loop; glasso_kkt() normalises on demand instead.
  fit$rho <- rho
  fit$penalize_diagonal <- penalize_diagonal
  fit$zero <- zero
  # Retain the input covariance so glasso_kkt() can certify the fit without the
  # caller having to carry `S` alongside the result.
  fit$S <- as.matrix(S)
  structure(fit, class = c("glasso_result", "list"))
}

#' Fit a graphical lasso over a path of penalties
#'
#' Runs [glasso_fit()] at every penalty in `rho`, warm-starting each fit from
#' the previous one. This is the kernel behind bootstrap and resampling
#' workflows that need many refits of the same covariance.
#'
#' @inheritParams glasso_fit
#' @param rho Numeric vector of non-negative penalties, used in the order
#'   supplied.
#' @param max_outer,max_inner Outer (column-sweep) and inner
#'   (coordinate-descent) iteration caps, as in [glasso_fit()].
#' @param tol_outer,tol_inner Convergence tolerances. The defaults are the
#'   looser path tolerances (`1e-4`), matching `glasso::glassopath()`: path
#'   scanning selects among well-separated models, so machine precision at every
#'   rung buys nothing. Refit the selected penalty with [glasso_fit()] when the
#'   returned matrix itself must be at full precision.
#'
#' @return An object of class `glasso_path_result`: a list with `w` and `wi`,
#'   each a `p x p x length(rho)` array indexed in the order `rho` was supplied,
#'   plus the `rho` vector itself. Use [as.data.frame()] for a tidy
#'   one-row-per-edge-per-penalty table.
#'
#' @seealso [glasso_fit()]
#' @examples
#' set.seed(1)
#' z <- rnorm(200)
#' x <- cbind(A = z + rnorm(200, 0, 0.5), B = z + rnorm(200, 0, 0.5),
#'            C = rnorm(200), D = rnorm(200))
#' path <- glasso_path(cov(x), rho = c(0.01, 0.05, 0.2))
#' path
#' as.data.frame(path)
#' @export
glasso_path <- function(S, rho,
                        penalize_diagonal = FALSE,
                        max_outer = 1e4, tol_outer = 1e-4,
                        max_inner = 1e4, tol_inner = 1e-4) {
  stopifnot(
    "`rho` must be a finite, non-negative numeric vector" =
      is.numeric(rho) && length(rho) >= 1L && all(is.finite(rho)) &&
        all(rho >= 0)
  )
  .ido_check_flag(penalize_diagonal, "penalize_diagonal")
  out <- .glassopath_fit(
    S = S, rholist = rho, penalize.diagonal = penalize_diagonal,
    max_outer = max_outer, tol_outer = tol_outer,
    max_inner = max_inner, tol_inner = tol_inner
  )
  out$rho <- rho
  out$rholist <- NULL
  out$penalize_diagonal <- penalize_diagonal
  structure(out, class = c("glasso_path_result", "list"))
}

#' Certify a graphical-lasso solution from its optimality conditions
#'
#' @description
#' Returns the largest violation of the graphical-lasso stationarity (KKT)
#' conditions. Because the objective is strictly convex, a value near zero
#' certifies the global optimum *directly from the estimand*, with no appeal to
#' any reference solver. For `W = Theta^{-1}` the subgradient conditions are
#'
#' \itemize{
#'   \item diagonal, unpenalised: \eqn{W_{ii} = S_{ii}};
#'   \item diagonal, penalised: \eqn{W_{ii} - S_{ii} = \rho_{ii}};
#'   \item off-diagonal with \eqn{\Theta_{ij} \neq 0}:
#'     \eqn{W_{ij} - S_{ij} = \rho_{ij}\,\mathrm{sign}(\Theta_{ij})};
#'   \item off-diagonal with \eqn{\Theta_{ij} = 0}:
#'     \eqn{|W_{ij} - S_{ij}| \le \rho_{ij}}.
#' }
#'
#' @param x A `glasso_result` from [glasso_fit()], or a precision matrix.
#' @param S Covariance the model was fit to. Required only when `x` is a bare
#'   matrix; taken from the fit otherwise.
#' @param rho Penalty (scalar or `p x p` matrix). Required only when `x` is a
#'   bare matrix.
#' @param penalize_diagonal Logical, whether the diagonal was penalised.
#'   Required only when `x` is a bare matrix.
#' @param zero Two-column matrix of hard-constrained `(row, col)` index pairs,
#'   as passed to [glasso_fit()]. Taken from the fit when `x` is a
#'   `glasso_result`. Constrained entries are excluded from the check: at a
#'   hard-constrained edge the inactive-edge inequality does not apply, because
#'   the equality constraint carries its own multiplier that absorbs the
#'   residual. Checking them anyway reports optimal fits as non-optimal.
#' @param active_tol Magnitude above which an off-diagonal entry counts as
#'   active. Default `1e-8`.
#'
#' @return A single non-negative number: the maximum absolute stationarity
#'   violation. Values near zero certify optimality.
#'
#' @seealso [glasso_fit()]
#' @examples
#' set.seed(1)
#' x <- matrix(rnorm(200 * 4), ncol = 4)
#' fit <- glasso_fit(cov(x), rho = 0.05)
#' glasso_kkt(fit)
#' @export
glasso_kkt <- function(x, S = NULL, rho = NULL, penalize_diagonal = NULL,
                       zero = NULL, active_tol = 1e-8) {
  # Validate a supplied flag BEFORE anything else, so an invalid value errors
  # cleanly instead of first emitting a confusing override warning.
  if (!is.null(penalize_diagonal)) {
    .ido_check_flag(penalize_diagonal, "penalize_diagonal")
  }
  if (inherits(x, "glasso_result")) {
    # Overriding the fit's own penalty measures the solution against a problem
    # it was not solving, which returns a large number that looks like a
    # failed certification. That is occasionally what a caller wants (probing
    # the surface), so it is allowed -- but never silently.
    .glasso_warn_override("rho", rho, x$rho)
    .glasso_warn_override("penalize_diagonal", penalize_diagonal,
                          x$penalize_diagonal)
    S <- S %||% x$S
    rho <- rho %||% x$rho
    penalize_diagonal <- penalize_diagonal %||% x$penalize_diagonal
    zero <- zero %||% x$zero
    Theta <- x$wi
    if (is.null(S)) {
      stop("`S` must be supplied: this `glasso_result` did not retain the ",
           "covariance it was fit to.", call. = FALSE)
    }
  } else {
    Theta <- x
    if (is.null(S) || is.null(rho)) {
      stop("`S` and `rho` are required when `x` is a bare precision matrix.",
           call. = FALSE)
    }
    penalize_diagonal <- penalize_diagonal %||% FALSE
  }
  # An unvalidated flag would be silently coerced by isTRUE() -- NA, 1, and
  # "yes" all becoming FALSE -- and would then certify against the wrong
  # stationarity condition while looking like a genuine violation.
  .ido_check_flag(penalize_diagonal, "penalize_diagonal")
  .glasso_kkt_violation(Theta, S, rho, active_tol = active_tol,
                        penalize_diagonal = penalize_diagonal,
                        zero = .glasso_check_zero(zero, S))
}

#' Warn when a caller overrides a `glasso_result`'s own fitting parameter with
#' a different value, which silently changes what is being certified.
#' @noRd
.glasso_warn_override <- function(name, supplied, stored) {
  if (is.null(supplied) || is.null(stored)) return(invisible(NULL))
  # `rho` is stored as a p x p matrix but callers legitimately re-pass the
  # scalar they fitted with, so recycle a length-1 value before comparing --
  # otherwise re-supplying the identical penalty would warn.
  if (length(supplied) == 1L && length(stored) > 1L) {
    supplied <- rep(supplied, length(stored))
  }
  same <- length(supplied) == length(stored) &&
    isTRUE(all.equal(as.vector(supplied), as.vector(stored)))
  if (same) return(invisible(NULL))
  warning(warningCondition(
    paste0("`", name, "` differs from the value this fit was made with; the ",
           "returned violation certifies the solution against a DIFFERENT ",
           "penalised problem. Omit `", name, "` to certify the fit itself."),
    class = "idiographic_glasso_kkt_override"))
  invisible(NULL)
}

#' Reject a covariance that is not positive semi-definite.
#'
#' `.glasso_fit()` checks only squareness, finiteness and symmetry, because it
#' runs inside `fit_graphical_var()`'s Rothman loop where an O(p^3) eigen
#' decomposition per call would be a severe regression (the covariances it is
#' handed are PSD by construction). The public entry point has no such
#' constraint and must not accept a matrix that is not a covariance at all: a
#' negative eigenvalue yields a precision matrix with a negative diagonal, and
#' every partial correlation derived from it is NaN.
#' @noRd
.glasso_check_psd <- function(S, tol = 1e-8) {
  # Structural problems (non-square, non-numeric, non-finite, asymmetric) are
  # .glasso_fit()'s to report, with its own messages. Defer to it rather than
  # letting eigen() fail first with a confusing one.
  if (!is.matrix(S) || !is.numeric(S) || nrow(S) != ncol(S) ||
      any(!is.finite(S)) || max(abs(S - t(S))) > 1e-8) {
    return(invisible(FALSE))
  }
  ev <- eigen((S + t(S)) / 2, symmetric = TRUE, only.values = TRUE)$values
  scale <- max(1, max(abs(ev)))
  if (min(ev) < -tol * scale) {
    stop(errorCondition(
      paste0("`S` is not a valid covariance matrix: its smallest eigenvalue ",
             "is ", format(min(ev), digits = 3), ". A covariance matrix is ",
             "positive semi-definite."),
      class = "idiographic_not_psd", call = NULL))
  }
  invisible(TRUE)
}

#' @noRd
.glasso_check_zero <- function(zero, S) {
  if (is.null(zero)) return(NULL)
  zero <- as.matrix(zero)
  p <- ncol(as.matrix(S))
  stopifnot(
    "`zero` must be a two-column matrix of (row, col) index pairs" =
      is.numeric(zero) && ncol(zero) == 2L,
    "`zero` indices must lie within the dimensions of `S`" =
      all(is.finite(zero)) && all(zero >= 1L) && all(zero <= p)
  )
  storage.mode(zero) <- "integer"
  zero
}

# ---- S3 methods ---------------------------------------------------------

#' Print a graphical-lasso fit
#'
#' @param x A `glasso_result` from [glasso_fit()].
#' @param digits Number of digits used for the printed matrices.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.glasso_result <- function(x, digits = 3, ...) {
  p <- ncol(x$wi)
  n_edges <- sum(x$wi[upper.tri(x$wi)] != 0)
  cat("Graphical Lasso Fit\n")
  cat(sprintf("  Variables:      %d\n", p))
  cat(sprintf("  Penalty (rho):  %s\n",
              if (length(unique(as.vector(x$rho))) == 1L)
                format(x$rho[1L], digits = digits) else "element-wise matrix"))
  cat(sprintf("  Diagonal:       %s\n",
              if (isTRUE(x$penalize_diagonal)) "penalised" else "unpenalised"))
  cat(sprintf("  Nonzero edges:  %d / %d\n", n_edges, p * (p - 1L) / 2L))
  cat("\n  as.data.frame(x) | glasso_kkt(x)\n")
  invisible(x)
}

#' Tidy a graphical-lasso fit
#'
#' @param x A `glasso_result` from [glasso_fit()].
#' @param row.names,optional Ignored; present for S3 consistency.
#' @param ... Ignored.
#' @return A `data.frame` with one row per unique variable pair and columns
#'   `from`, `to`, `precision` (the \eqn{\Theta} entry) and `weight` (the
#'   partial correlation implied by \eqn{\Theta}).
#' @export
as.data.frame.glasso_result <- function(x, row.names = NULL, optional = FALSE,
                                        ...) {
  .glasso_edge_table(x$wi)
}

#' Print a graphical-lasso path
#'
#' @param x A `glasso_path_result` from [glasso_path()].
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.glasso_path_result <- function(x, ...) {
  cat("Graphical Lasso Path\n")
  cat(sprintf("  Variables:      %d\n", dim(x$wi)[1L]))
  cat(sprintf("  Penalties:      %d (%s to %s)\n", length(x$rho),
              format(min(x$rho)), format(max(x$rho))))
  cat(sprintf("  Nonzero edges:  %s\n", paste(
    vapply(seq_along(x$rho), function(k) {
      w <- x$wi[, , k]
      as.character(sum(w[upper.tri(w)] != 0))
    }, character(1)), collapse = ", ")))
  cat("\n  as.data.frame(x)\n")
  invisible(x)
}

#' Tidy a graphical-lasso path
#'
#' @param x A `glasso_path_result` from [glasso_path()].
#' @param row.names,optional Ignored; present for S3 consistency.
#' @param ... Ignored.
#' @return A `data.frame` with one row per variable pair per penalty and
#'   columns `rho`, `from`, `to`, `precision` and `weight`.
#' @export
as.data.frame.glasso_path_result <- function(x, row.names = NULL,
                                             optional = FALSE, ...) {
  rows <- lapply(seq_along(x$rho), function(k) {
    tab <- .glasso_edge_table(x$wi[, , k])
    cbind(rho = x$rho[k], tab)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' One row per unique variable pair, with precision and partial correlation.
#' @noRd
.glasso_edge_table <- function(Theta) {
  p <- ncol(Theta)
  labels <- colnames(Theta)
  if (is.null(labels)) labels <- paste0("V", seq_len(p))
  # A precision matrix has a strictly positive diagonal. stats::cov2cor() only
  # WARNS on a non-positive one and returns non-finite partial correlations,
  # which would flow into the tidy table looking like real edges. Refuse
  # instead. glasso_fit() never produces such a matrix (it caps the precision
  # diagonal), so this guards hand-built and externally supplied input.
  if (anyNA(diag(Theta)) || any(diag(Theta) <= 0)) {
    stop(errorCondition(
      paste0("Precision matrix has a non-positive or missing diagonal entry, ",
             "so partial correlations are undefined. A valid precision ",
             "matrix is positive definite."),
      class = "idiographic_bad_precision", call = NULL))
  }
  pcor <- -stats::cov2cor(Theta)
  diag(pcor) <- 0
  idx <- which(upper.tri(Theta), arr.ind = TRUE)
  out <- data.frame(
    from = labels[idx[, "row"]],
    to = labels[idx[, "col"]],
    precision = Theta[idx],
    weight = pcor[idx],
    stringsAsFactors = FALSE
  )
  out <- out[order(-abs(out$weight)), , drop = FALSE]
  rownames(out) <- NULL
  out
}
