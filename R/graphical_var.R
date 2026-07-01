#' Graphical VAR Estimation
#'
#' Estimate a graphical vector autoregressive (GVAR) model from time series or
#' panel data. Jointly estimates a sparse temporal network (L1-penalized VAR
#' coefficients) and a sparse contemporaneous network (graphical lasso on
#' residuals) using EBIC model selection over a lambda grid.
#'
#' This is a clean-room reimplementation of the Rothman/Epskamp two-step
#' estimator that is **numerically equivalent to**
#' \code{graphicalVAR::graphicalVAR()}: identical data preparation
#' (global scaling, optional within-person centering, intercept column,
#' lag-1 construction within id/day blocks), identical lambda grids
#' (\code{generate_lambdas}), the coupled MRCE beta-update / glasso kappa-update
#' loop, the unpenalized-likelihood EBIC, and the same tie-broken model
#' selection. On well-conditioned data it agrees with \code{graphicalVAR} to
#' machine precision (~1e-11); on rank-deficient data (n close to the number of
#' parameters) it agrees to the MRCE inner-solver tolerance (~1e-3), which
#' \code{graphicalVAR} shares.
#'
#' @param data A data.frame or matrix with columns for variables, and optionally
#'   id, day, beep columns for panel/ESM data.
#' @param vars Character vector of variable names.
#' @param id Character. Name of the person-ID column. If NULL, assumes single
#'   subject.
#' @param day Character. Name of the day/session column. Default: NULL.
#' @param beep Character. Name of the beep/measurement column. Default: NULL.
#' @param lags Integer. Lag order. Only \code{1} is supported (matches
#'   \code{graphicalVAR}'s default; multi-lag is not implemented). Default: 1.
#' @param n_lambda Integer. Number of lambda values per penalty dimension.
#'   Default: 50 (matches \code{graphicalVAR}'s \code{nLambda}).
#' @param gamma Numeric. EBIC hyperparameter (0 = BIC, higher = sparser).
#'   Default: 0.5.
#' @param scale Logical. Whether to standardize variables. Default: TRUE.
#' @param center_within Logical. Whether to center within person when more than
#'   one id is present (removes between-person variance). Default: TRUE.
#' @param lambda_min_ratio Numeric. Ratio of min/max lambda applied to both the
#'   beta and kappa grids unless overridden per-dimension. Default: 0.05.
#' @param lambda_min_kappa,lambda_min_beta Numeric or \code{NULL}. Per-dimension
#'   min/max lambda ratios (matching \code{graphicalVAR}'s \code{lambda_min_kappa}
#'   / \code{lambda_min_beta}). When \code{NULL}, fall back to
#'   \code{lambda_min_ratio}.
#' @param penalize_diagonal Logical. Penalize the autoregressive diagonal in
#'   beta. Default: TRUE (matches \code{graphicalVAR}).
#' @param regularize_mat_beta Optional numeric/logical matrix
#'   (\code{p x p} or \code{p x (p+1)}) of per-element beta penalty multipliers
#'   (matches \code{graphicalVAR}'s \code{regularize_mat_beta}). \code{NULL} uses
#'   \code{penalize_diagonal}.
#' @param regularize_mat_kappa Optional \code{p x p} numeric/logical matrix of
#'   per-element kappa penalty multipliers (matches
#'   \code{graphicalVAR}'s \code{regularize_mat_kappa}). \code{NULL} penalizes all
#'   off-diagonals.
#' @param maxit_in,maxit_out Integer. Max inner (beta) / outer (beta-kappa)
#'   iterations. Defaults 100 (matches \code{maxit.in} / \code{maxit.out}).
#' @param delete_missings Logical. Drop rows with missing current/lagged values.
#'   Default TRUE (matches \code{deleteMissings}).
#' @param likelihood Either \code{"unpenalized"} (default; refit precision for
#'   the EBIC, matching \code{graphicalVAR}) or \code{"penalized"} (use the
#'   regularized kappa directly).
#' @param ebic_tol Numeric. Tolerance for the EBIC tie-break. Default 1e-4.
#' @param mimic Character. Only \code{"current"} is supported (legacy
#'   compatibility modes are ignored with a warning).
#' @param verbose Logical. Emit progress messages. Default FALSE.
#' @param lambda_beta Numeric scalar (or vector), or \code{NULL}. When supplied,
#'   the temporal penalty is pinned to this value instead of being EBIC-selected
#'   over a grid -- matching \code{graphicalVAR}'s \code{lambda_beta} argument
#'   (e.g. \code{lambda_beta = 0.1}). Default \code{NULL} (EBIC grid).
#' @param lambda_kappa Numeric scalar (or vector), or \code{NULL}. As
#'   \code{lambda_beta} but for the contemporaneous (kappa) penalty.
#' @param min_obs Integer or \code{NULL}. Keep only subjects with at least this
#'   many observations (counts taken from \code{data}). Default \code{NULL}.
#' @param subject Optional vector naming the exact subject(s) to analyse.
#'   Default \code{NULL} (all subjects).
#'
#' @return A list of class \code{gvar_result} containing:
#' \describe{
#'   \item{beta}{Temporal coefficient matrix, outcome x (intercept + predictors),
#'     in \code{graphicalVAR}'s convention.}
#'   \item{temporal}{The p x p temporal slice \code{beta[, -1]} as
#'     \code{[outcome, predictor]} (intercept dropped).}
#'   \item{kappa}{Precision matrix (p x p, symmetric).}
#'   \item{PCC}{Partial contemporaneous correlations \code{-cov2cor(kappa)},
#'     diagonal zeroed.}
#'   \item{PDC}{Partial directed correlations.}
#'   \item{contemporaneous}{Alias for \code{PCC}.}
#'   \item{labels}{Variable names.}
#'   \item{n_obs}{Number of valid lag-pair observations.}
#'   \item{lambda_beta, lambda_kappa}{Selected penalties.}
#'   \item{gamma, EBIC}{EBIC gamma used and the selected EBIC.}
#' }
#'
#' @references
#' Epskamp, S., Waldorp, L. J., Mottus, R., & Borsboom, D. (2018).
#' The Gaussian Graphical Model in Cross-Sectional and Time-Series Data.
#' \emph{Multivariate Behavioral Research}, 53(4), 453-480.
#'
#' Rothman, A. J., Levina, E., & Zhu, J. (2010). Sparse multivariate regression
#' with covariance estimation. \emph{JCGS}, 19(4), 947-962.
#'
#' @importFrom stats cov2cor sd
#' @export
graphical_var <- function(data,
                          vars,
                          id = NULL,
                          day = NULL,
                          beep = NULL,
                          lags = 1L,
                          n_lambda = 50L,
                          gamma = 0.5,
                          scale = TRUE,
                          center_within = TRUE,
                          lambda_min_ratio = 0.05,
                          lambda_min_kappa = NULL,
                          lambda_min_beta = NULL,
                          penalize_diagonal = TRUE,
                          lambda_beta = NULL,
                          lambda_kappa = NULL,
                          regularize_mat_beta = NULL,
                          regularize_mat_kappa = NULL,
                          maxit_in = 100L,
                          maxit_out = 100L,
                          delete_missings = TRUE,
                          likelihood = c("unpenalized", "penalized"),
                          ebic_tol = 1e-4,
                          mimic = "current",
                          verbose = FALSE,
                          min_obs = NULL,
                          subject = NULL) {

  likelihood <- match.arg(likelihood)
  stopifnot(is.data.frame(data) || is.matrix(data))
  stopifnot(is.character(vars), length(vars) >= 2L)
  stopifnot(is.numeric(gamma), length(gamma) == 1L, gamma >= 0)
  stopifnot(is.numeric(n_lambda), length(n_lambda) == 1L, n_lambda >= 2L)
  stopifnot(is.numeric(lambda_min_ratio), length(lambda_min_ratio) == 1L,
            is.finite(lambda_min_ratio), lambda_min_ratio > 0,
            lambda_min_ratio < 1)
  stopifnot(is.numeric(maxit_in), maxit_in >= 1L,
            is.numeric(maxit_out), maxit_out >= 1L,
            is.numeric(ebic_tol), length(ebic_tol) == 1L, ebic_tol >= 0)
  .ido_check_flag(scale, "scale")
  .ido_check_flag(center_within, "center_within")
  .ido_check_flag(penalize_diagonal, "penalize_diagonal")
  .ido_check_flag(delete_missings, "delete_missings")
  .ido_check_flag(verbose, "verbose")
  if (!identical(as.character(mimic), "current")) {
    warning("`mimic` only supports \"current\"; ignoring '", mimic, "'.",
            call. = FALSE)
  }
  # Only single-lag (lags = 1) is supported; graphicalVAR's multi-lag path is
  # rarely used and its upstream `shift` handling is unreliable.
  if (!(length(lags) == 1L && lags == 1L)) {
    stop("`lags` must be 1; multi-lag VAR is not supported.", call. = FALSE)
  }
  # Per-dimension lambda minima (graphicalVAR's lambda_min_kappa/beta); fall back
  # to the shared lambda_min_ratio.
  lmin_k <- lambda_min_kappa %||% lambda_min_ratio
  lmin_b <- lambda_min_beta  %||% lambda_min_ratio
  stopifnot(is.numeric(lmin_k), lmin_k > 0, lmin_k < 1,
            is.numeric(lmin_b), lmin_b > 0, lmin_b < 1)
  # Fixed-penalty override (matches graphicalVAR's lambda_beta / lambda_kappa):
  # supply a scalar (or vector) to pin that penalty instead of EBIC-selecting it.
  if (!is.null(lambda_beta)) {
    stopifnot(is.numeric(lambda_beta), length(lambda_beta) >= 1L,
              all(is.finite(lambda_beta)), all(lambda_beta >= 0))
  }
  if (!is.null(lambda_kappa)) {
    stopifnot(is.numeric(lambda_kappa), length(lambda_kappa) >= 1L,
              all(is.finite(lambda_kappa)), all(lambda_kappa >= 0))
  }
  d <- length(vars)
  if (!is.null(regularize_mat_beta)) {
    stopifnot(is.matrix(regularize_mat_beta))
  }
  if (!is.null(regularize_mat_kappa)) {
    stopifnot(is.matrix(regularize_mat_kappa),
              nrow(regularize_mat_kappa) == d,
              ncol(regularize_mat_kappa) == d)
    regularize_mat_kappa <- regularize_mat_kappa * 1   # logical -> numeric
  }

  data <- as.data.frame(data)
  if (!all(vars %in% names(data))) {
    stop("Variables not found in data: ",
         paste(setdiff(vars, names(data)), collapse = ", "), call. = FALSE)
  }
  .ido_check_col(id,   "id",   data)
  .ido_check_col(day,  "day",  data)
  .ido_check_col(beep, "beep", data)

  # Keep only well-sampled subjects (counts taken from the data frame).
  data <- .ido_keep(data, id, min_obs, subject)

  .ido_check_numeric_vars(data, vars)

  # ---- 1. Data preparation (matches graphicalVAR::tsData, lags = 1) ----
  if (verbose) message("Preparing lagged data ...")
  ts <- .gvar_tsdata(data, vars, id, day, beep, scale, center_within,
                     delete_missings)
  data_c <- ts$data_c       # n x p   (current)
  data_l <- ts$data_l       # n x p+1 (intercept + lag-1)
  n <- nrow(data_c)
  if (n < d + 1L) {
    stop("Too few lag pairs (", n, ") for ", d, " variables.", call. = FALSE)
  }

  # ---- 2. Lambda grids (matches graphicalVAR::generate_lambdas) ----
  # A fixed lambda_beta / lambda_kappa pins that penalty (EBIC then selects over
  # the other dimension only, or over a single cell if both are fixed). Generate
  # only the grids that are actually needed -- when both penalties are fixed,
  # skip .gvar_genlambda() entirely (it runs an invGlasso/eigen, sometimes a full
  # glasso, that would be discarded).
  need_grid <- is.null(lambda_beta) || is.null(lambda_kappa)
  lams <- if (need_grid) {
    .gvar_genlambda(data_l, data_c, n_lambda, n_lambda, lmin_k, lmin_b)
  } else {
    list(lambda_beta = NULL, lambda_kappa = NULL)
  }
  if (!is.null(lambda_beta))  lams$lambda_beta  <- lambda_beta
  if (!is.null(lambda_kappa)) lams$lambda_kappa <- lambda_kappa
  grid <- expand.grid(kappa = lams$lambda_kappa, beta = lams$lambda_beta)

  # ---- 3. Fit every (lambda_beta, lambda_kappa) cell ----
  if (verbose) message("Fitting ", nrow(grid), " (lambda_beta, lambda_kappa) ",
                       "cells ...")
  est <- lapply(seq_len(nrow(grid)), function(i) {
    .gvar_rothman(data_l, data_c, grid$beta[i], grid$kappa[i],
                  gamma = gamma, penalize_diagonal = penalize_diagonal,
                  maxit_out = maxit_out, maxit_in = maxit_in,
                  regularize_mat_beta = regularize_mat_beta,
                  regularize_mat_kappa = regularize_mat_kappa,
                  likelihood = likelihood)
  })
  grid$ebic <- vapply(est, function(e) e$EBIC, numeric(1))

  # ---- 4. EBIC selection with graphicalVAR's tie-break ----
  # which() drops cells whose EBIC is NA/NaN (a degenerate (lambda) pairing),
  # so one bad cell can't inject an NA index into the candidate set.
  min_ebic <- min(grid$ebic, na.rm = TRUE)
  cand <- which(abs(grid$ebic - min_ebic) < ebic_tol)
  cand <- cand[grid$kappa[cand] == min(grid$kappa[cand])]
  sel <- cand[grid$beta[cand] == min(grid$beta[cand])][1L]
  R <- est[[sel]]

  # ---- 5. Assemble result ----
  beta <- R$beta                       # outcome x (intercept + predictors)
  kappa <- R$kappa
  rownames(beta) <- vars
  colnames(beta) <- colnames(data_l)
  dimnames(kappa) <- list(vars, vars)

  temporal <- beta[, -1L, drop = FALSE]  # [outcome, predictor]
  dimnames(temporal) <- list(vars, vars)

  pcc <- .gvar_compute_pcc(kappa)
  pdc <- .gvar_compute_pdc(beta, kappa)
  dimnames(pcc) <- dimnames(pdc) <- list(vars, vars)

  model <- list(
    beta            = beta,
    temporal        = temporal,
    kappa           = kappa,
    PCC             = pcc,
    PDC             = pdc,
    contemporaneous = pcc,
    labels          = vars,
    n_obs           = n,
    lambda_beta     = grid$beta[sel],
    lambda_kappa    = grid$kappa[sel],
    gamma           = gamma,
    EBIC            = grid$ebic[sel],
    likelihood      = likelihood
  )
  .ido_group_result(
    "gvar_result",
    list(
      temporal = .ido_wrap(t(temporal), method = "relative", directed = TRUE),
      contemporaneous = .ido_wrap(pcc, method = "co_occurrence",
                                  directed = FALSE)
    ),
    model
  )
}


# ============================================================
# Internal: data preparation (graphicalVAR::tsData, lags = 1)
# ============================================================

#' Build current/lagged matrices matching tsData (lags = 1).
#'
#' Global per-variable scaling (always centered), optional within-person
#' centering when >1 id, lag-1 construction within (id, day) blocks, and
#' (when `delete_missings`) deletion of rows with missing current or lagged
#' values.
#' @noRd
.gvar_tsdata <- function(data, vars, id, day, beep, scale, center_within,
                         delete_missings = TRUE) {
  data <- as.data.frame(data)

  # global scale per variable (center always TRUE, scale optional)
  for (v in vars) {
    data[[v]] <- as.numeric(scale(data[[v]], center = TRUE, scale = scale))
  }

  idv  <- if (is.null(id))  rep(1L, nrow(data)) else data[[id]]
  dayv <- if (is.null(day)) rep(1L, nrow(data)) else data[[day]]

  # within-person centering (center only) when more than one id
  if (isTRUE(center_within) && length(unique(idv)) > 1L) {
    for (v in vars) {
      m <- stats::ave(data[[v]], idv, FUN = function(z) mean(z, na.rm = TRUE))
      data[[v]] <- data[[v]] - m
    }
  }

  # order by id, day, then beep (or original row order within block)
  key <- if (is.null(beep)) seq_len(nrow(data)) else data[[beep]]
  ord <- order(idv, dayv, key)
  data <- data[ord, , drop = FALSE]
  idv  <- idv[ord]
  dayv <- dayv[ord]

  Y <- as.matrix(data[, vars, drop = FALSE])

  # lag-1 within (id, day) blocks: a row's lag is the previous row iff that
  # previous row belongs to the same block; first row of each block -> NA.
  blk  <- paste(idv, dayv, sep = "\r")
  same <- c(FALSE, blk[-1L] == blk[-length(blk)])
  lag  <- matrix(NA_real_, nrow(Y), ncol(Y))
  lag[same, ] <- Y[which(same) - 1L, , drop = FALSE]

  keep <- if (isTRUE(delete_missings)) {
    !(rowSums(is.na(Y)) > 0 | rowSums(is.na(lag)) > 0)
  } else {
    rep(TRUE, nrow(Y))
  }
  out <- list(data_c = Y[keep, , drop = FALSE],
              data_l = cbind(1, lag[keep, , drop = FALSE]))
  if (isTRUE(delete_missings) && nrow(out$data_c) == 0L) {
    stop("No complete lag pairs remain after deleting missing values.",
         call. = FALSE)
  }
  out
}


# ============================================================
# Internal: lambda grid (graphicalVAR::generate_lambdas)
# ============================================================

#' @noRd
.gvar_invGlasso <- function(x) {
  if (all(eigen(x, symmetric = TRUE, only.values = TRUE)$values >
          sqrt(.Machine$double.eps))) {
    solve(x)
  } else {
    .glasso_fit(x, 0.05, penalize.diagonal = FALSE)$wi
  }
}

#' @noRd
.gvar_genlambda <- function(X, Y, n_lk, n_lb, lmin_k = 0.05, lmin_b = 0.05) {
  n <- nrow(Y)
  corY <- stats::cov2cor(crossprod(Y) / n)
  lk_max <- max(abs(corY[upper.tri(corY)]))
  if (!is.finite(lk_max) || lk_max <= 0) {
    stop("Cannot build the kappa lambda grid: the current variables are ",
         "degenerate (constant or perfectly collinear after scaling). ",
         "Check for zero-variance variables.", call. = FALSE)
  }
  lam_k <- exp(seq(log(lk_max), log(lmin_k * lk_max), length.out = n_lk))

  Yinv <- .gvar_invGlasso(crossprod(Y))
  lb_max <- max(abs(crossprod(X, Y) %*% Yinv))
  if (!is.finite(lb_max) || lb_max <= 0) {
    stop("Cannot build the beta lambda grid: the lagged predictors are ",
         "degenerate (constant or perfectly collinear).", call. = FALSE)
  }
  lam_b <- exp(seq(log(lb_max), log(lmin_b * lb_max), length.out = n_lb))

  list(lambda_kappa = lam_k, lambda_beta = lam_b)
}


# ============================================================
# Internal: Rothman/MRCE joint estimator (graphicalVAR::Rothmana)
# ============================================================

#' @noRd
.gvar_soft <- function(z, g) sign(z) * pmax(abs(z) - g, 0)

#' MRCE beta-update (coordinate descent), equivalent to graphicalVAR's Beta_C.
#'
#' Minimises (1/n) tr{ kappa (Y - XB)'(Y - XB) } + sum lambda_mat * |B|.
#' @noRd
.gvar_beta <- function(kappa, beta, X, Y, lambda_mat,
                       convergence = 1e-4, maxit = 100L) {
  n <- nrow(X); nX <- ncol(X); nY <- ncol(Y)
  Sxx <- crossprod(X)
  Sxy <- crossprod(X, Y)
  Om  <- kappa
  B <- beta
  U <- Sxy - Sxx %*% B
  for (it in seq_len(maxit)) {
    B_old <- B
    for (cc in seq_len(nY)) {
      for (r in seq_len(nX)) {
        den <- Sxx[r, r] * Om[cc, cc]
        z   <- B[r, cc] + sum(U[r, ] * Om[, cc]) / den
        b   <- .gvar_soft(z, lambda_mat[r, cc] * n / den)
        delta <- b - B[r, cc]
        if (delta != 0) {
          B[r, cc] <- b
          U[, cc] <- U[, cc] - Sxx[, r] * delta
        }
      }
    }
    if (sum(abs(B - B_old)) < convergence * sum(abs(B))) break
  }
  B
}

#' kappa-update: graphical lasso on the residual covariance.
#'
#' `regularize_mat_kappa` (a `p x p` logical/0-1 mask, default penalise all
#' off-diagonals) maps to glasso's element-wise penalty `regularize_mat_kappa *
#' lambda_kappa`, matching graphicalVAR::Kappa.
#' @noRd
.gvar_kappa <- function(beta, X, Y, lambda_kappa, regularize_mat_kappa = NULL) {
  n <- nrow(Y)
  R <- Y - X %*% beta
  SigmaR <- crossprod(R) / n
  if (is.null(regularize_mat_kappa)) {
    # Scalar penalty, off-diagonal only (default mask penalises off-diagonals).
    wi <- .glasso_fit(SigmaR, rho = lambda_kappa, penalize.diagonal = FALSE)$wi
  } else {
    # Element-wise penalty matrix. Pass penalize.diagonal = TRUE so the matrix's
    # diagonal (diag(Rho)) is honoured -- matching glasso(SigmaR, mask*lambda).
    # The default mask has a 0 diagonal, so this reduces to the scalar case.
    rho <- regularize_mat_kappa * lambda_kappa
    wi <- .glasso_fit(SigmaR, rho = rho, penalize.diagonal = TRUE)$wi
  }
  (wi + t(wi)) / 2
}

#' Build the beta penalty matrix (graphicalVAR::Rothmana lambda_mat logic).
#' @noRd
.gvar_lambda_mat <- function(lambda_beta, nX, nY, penalize_diagonal,
                             regularize_mat_beta) {
  if (is.null(regularize_mat_beta)) {
    lambda_mat <- matrix(lambda_beta, nX, nY)
    if (!penalize_diagonal) {
      # beta is (intercept + p) x p, so the AR diagonal sits at [i + 1, i].
      for (i in seq_len(nY)) lambda_mat[i + 1L, i] <- 0
    }
  } else {
    lambda_mat <- lambda_beta * t(regularize_mat_beta)
    if (nrow(lambda_mat) == nX - 1L) {
      # Intercept is beta's FIRST row (data_l = cbind(1, lag...)), so the
      # unpenalised intercept row must be PREPENDED, not appended -- matching
      # graphicalVAR's Rothmana (rbind(0, t(M))). Appending it instead shifts
      # every predictor penalty down one row.
      lambda_mat <- rbind(0, lambda_mat)
    }
    if (nrow(lambda_mat) != nX || ncol(lambda_mat) != nY) {
      stop("`regularize_mat_beta` has the wrong dimensions (expected ",
           nY, " x ", nY, " or ", nY, " x ", nX, ").", call. = FALSE)
    }
  }
  lambda_mat[1L, ] <- 0                          # intercept column never penalised
  lambda_mat
}

#' One (lambda_beta, lambda_kappa) cell: alternate beta/kappa, then EBIC.
#' @noRd
.gvar_rothman <- function(X, Y, lambda_beta, lambda_kappa, gamma,
                          penalize_diagonal = TRUE,
                          convergence = 1e-4,
                          maxit_out = 100L, maxit_in = 100L,
                          regularize_mat_beta = NULL,
                          regularize_mat_kappa = NULL,
                          likelihood = c("unpenalized", "penalized")) {
  likelihood <- match.arg(likelihood)
  n <- nrow(X); nX <- ncol(X); nY <- ncol(Y)

  lambda_mat <- .gvar_lambda_mat(lambda_beta, nX, nY, penalize_diagonal,
                                 regularize_mat_beta)

  beta_ridge <- solve(crossprod(X) + lambda_beta * diag(nX), crossprod(X, Y))
  beta <- matrix(0, nX, nY)
  it <- 0L
  repeat {
    it <- it + 1L
    kappa <- .gvar_kappa(beta, X, Y, lambda_kappa, regularize_mat_kappa)
    beta_old <- beta
    beta <- .gvar_beta(kappa, beta, X, Y, lambda_mat, convergence, maxit_in)
    if (sum(abs(beta - beta_old)) < convergence * sum(abs(beta_ridge))) break
    if (it > maxit_out) break
  }

  WS <- (crossprod(Y) - crossprod(Y, X %*% beta) -
           crossprod(beta, crossprod(X, Y)) +
           crossprod(beta, crossprod(X) %*% beta)) / n
  WS <- (WS + t(WS)) / 2

  if (likelihood == "unpenalized") {
    # Refit precision on the residual covariance with kappa's zero-pattern fixed.
    zi <- which(kappa == 0, arr.ind = TRUE)
    refit <- if (nrow(zi) == 0L) .glasso_fit(WS, rho = 0) else
      .glasso_fit(WS, rho = 0, zero = zi)
    lik1 <- determinant(refit$wi)$modulus[1]
    lik2 <- sum(diag(refit$wi %*% WS))
  } else {
    # Penalised likelihood: use the regularised kappa directly.
    lik1 <- determinant(kappa)$modulus[1]
    lik2 <- sum(diag(kappa %*% WS))
  }

  pdO <- sum(kappa[upper.tri(kappa)] != 0)
  pdB <- sum(beta[lambda_mat != 0] != 0)
  LLk <- (n / 2) * (lik1 - lik2)
  ebic <- -2 * LLk + log(n) * (pdO + pdB) +
    (pdO + pdB) * 4 * gamma * log(2 * nY)

  list(beta = t(beta), kappa = kappa, EBIC = as.numeric(ebic))
}


# ============================================================
# Internal: PCC and PDC (graphicalVAR::computePCC / computePDC)
# ============================================================

#' @noRd
.gvar_compute_pcc <- function(kappa) {
  pcc <- -stats::cov2cor(kappa)
  diag(pcc) <- 0
  (pcc + t(pcc)) / 2
}

#' @noRd
.gvar_compute_pdc <- function(beta, kappa) {
  if (ncol(beta) == nrow(beta) + 1L) beta <- beta[, -1L, drop = FALSE]
  sigma <- solve(kappa)
  denom <- sqrt(diag(sigma) %o% diag(kappa) + beta^2)
  denom[denom == 0] <- 1
  t(beta / denom)
}


# ============================================================
# S3 Methods
# ============================================================

#' Print Method for gvar_result
#'
#' @param x A \code{gvar_result} object.
#' @param digits Number of digits used for printed network matrices.
#' @param ... Additional arguments (ignored).
#'
#' @return The input object, invisibly.
#'
#' @export
print.gvar_result <- function(x, digits = 2, ...) {
  d <- length(x$labels)
  n_temp <- sum(x$temporal != 0)
  n_contemp <- sum(x$PCC[upper.tri(x$PCC)] != 0)

  cat("Graphical VAR Result\n")
  cat(sprintf("  Variables:      %d (%s)\n", d, paste(x$labels, collapse = ", ")))
  cat(sprintf("  Observations:   %d\n", x$n_obs))
  cat(sprintf("  Temporal edges: %d / %d\n", n_temp, d * d))
  cat(sprintf("  Contemp edges:  %d / %d\n", n_contemp, d * (d - 1) / 2))
  cat(sprintf("  EBIC:           %.2f (gamma=%.2f)\n", x$EBIC, x$gamma))
  cat(sprintf("  Lambda:         beta=%.4f, kappa=%.4f\n",
              x$lambda_beta, x$lambda_kappa))
  .ido_print_networks(x, digits = digits)
  cat("\n  plot(x) | plot(x, layer = \"temporal\")",
      "\n  edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)\n")
  invisible(x)
}

#' Coerce a gvar_result to plottable netobjects
#'
#' Returns the two networks a graphical VAR contains as Nestimate netobjects,
#' so each renders directly with \code{cograph::splot()} (or any netobject verb)
#' without the caller transposing matrices or dropping intercept columns. The
#' temporal network is oriented \code{[from = predictor(t-1), to = outcome(t)]}.
#'
#' @param x A \code{gvar_result}.
#' @param ... Ignored.
#' @return A \code{netobject_group}: a named list with \code{$temporal}
#'   (directed) and \code{$contemporaneous} (undirected) netobjects.
#' @export
as_netobject.gvar_result <- function(x, ...) {
  .ido_network_group(x)
}

#' Summary Method for gvar_result
#'
#' @param object A \code{gvar_result} object.
#' @param ... Additional arguments (ignored).
#'
#' @return A tidy \code{data.frame} of per-network metrics: one row per network
#'   (\code{temporal}, \code{contemporaneous}) with \code{n_nodes},
#'   \code{n_edges}, \code{density}, \code{mean_abs_weight}, \code{n_positive},
#'   \code{n_negative}. Use \code{edges(object)} / \code{coefs(object)} for the
#'   estimates and \code{nodes(object)} for node strengths.
#'
#' @export
summary.gvar_result <- function(object, ...) {
  .tidy_over_group(as_netobject(object), .net_metrics)
}
