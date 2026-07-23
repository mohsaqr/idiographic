# ---- Native Bayesian VAR (graphical VAR analogue, Mplus-targeted) ------------
#
# Single-level Bayesian VAR(1) matching Mplus's ESTIMATOR = BAYES time-series /
# regression output. This is the *unregularized* Bayesian analogue of
# fit_graphical_var(): Mplus has no graphical lasso, so the honest "match Mplus"
# object is a full (non-sparse) VAR(1) with an inverse-Wishart residual
# precision, from which the contemporaneous partial-correlation network is
# derived exactly as fit_graphical_var() derives its PCC.
#
# Model (per pooled, within-centred series), verified against a real Mplus .out:
#   y_t = c + B y_{t-1} + e_t ,   e_t ~ N(0, Sigma)
#   priors:  c, B ~ N(0, infinity) (flat);  Sigma ~ IW(0, -(p+1))
# The joint posterior is Normal-Inverse-Wishart; a two-block Gibbs
#   Sigma | B ~ IW((Y - XB)'(Y - XB), n - (p+1)) ,  vec(B) | Sigma ~ matrix-normal
# targets it exactly. Point estimates = posterior medians (Mplus default).

#' Build a Bayesian VAR(1) network (unregularized, Mplus-targeted)
#'
#' @description Native, pure-R Bayesian VAR(1) that reproduces Mplus's Bayesian
#'   (DSEM/time-series) estimates without needing Mplus. It is the unregularized
#'   Bayesian counterpart of [fit_graphical_var()]: instead of a graphical-lasso /
#'   EBIC sparse fit, it estimates a full VAR(1) with a flat prior on the
#'   temporal coefficients and an inverse-Wishart prior on the residual
#'   precision, then reports the temporal network `B` and the contemporaneous
#'   partial-correlation network derived from the residual covariance. With more
#'   than one subject the data are within-person centred and pooled (as in
#'   [fit_graphical_var()]).
#'
#' @param data A `data.frame` or matrix.
#' @param vars Character vector of variable names (length >= 2).
#' @param id Character. Person-ID column, or `NULL` for a single series.
#' @param day Character. Day/session column, or `NULL`.
#' @param beep Character. Beep/measurement column, or `NULL`.
#' @param lags Integer lag order; only `1` is supported.
#' @param scale Logical. Global standardization of each variable. Default `TRUE`.
#' @param center_within Logical. Within-person centre when >1 id (removes
#'   between-person variance, as in [fit_graphical_var()]). Default `TRUE`.
#' @param n_iter,n_burnin,n_chains,thin MCMC controls. Defaults `4000`,
#'   `n_iter/2`, `2`, `1`.
#' @param seed Integer or `NULL`. Base seed (chain `c` uses `seed + c`).
#' @param min_obs Integer or `NULL`. Keep only subjects with at least this many
#'   observations.
#' @param subject Optional vector naming the exact subject(s) to analyse.
#' @param verbose Logical. Progress messages. Default `FALSE`.
#'
#' @return A `var_bayes_result` object (a cograph group with `temporal` and
#'   `contemporaneous` netobjects) carrying `beta`, `temporal`, `kappa`, `PCC`,
#'   `PDC`, posterior draws, and a tidy `coefs()` table (posterior median, SD,
#'   95% CI, one-tailed p, significance by CI excluding 0).
#'
#' @examples
#' \donttest{
#' set.seed(1)
#' y <- matrix(0, 200, 2)
#' for (t in 2:200) y[t, ] <- c(0.4, 0.3) * y[t - 1, ] + rnorm(2)
#' d <- data.frame(A = y[, 1], B = y[, 2])
#' fit <- fit_var_bayes(d, vars = c("A", "B"), n_iter = 500, seed = 1)
#' print(fit)
#' coefs(fit)
#' }
#' @seealso [fit_graphical_var()] (regularized GLASSO/EBIC), [fit_var()] (OLS),
#'   [fit_mlvar_bayes()] (multilevel Bayesian VAR).
#' @export
fit_var_bayes <- function(data, vars,
                            id = NULL, day = NULL, beep = NULL,
                            lags = 1L,
                            scale = TRUE,
                            center_within = TRUE,
                            n_iter = 4000L,
                            n_burnin = NULL,
                            n_chains = 2L,
                            thin = 1L,
                            seed = NULL,
                            min_obs = NULL,
                            subject = NULL,
                            verbose = FALSE) {
  stopifnot(is.data.frame(data) || is.matrix(data))
  stopifnot(is.character(vars), length(vars) >= 2L)
  stopifnot(is.numeric(lags), length(lags) == 1L, lags == 1L)
  stopifnot(is.numeric(n_iter), n_iter >= 100L,
            is.numeric(n_chains), n_chains >= 1L,
            is.numeric(thin), thin >= 1L)
  .ido_check_flag(scale, "scale")
  .ido_check_flag(center_within, "center_within")
  .ido_check_flag(verbose, "verbose")
  if (is.null(n_burnin)) n_burnin <- as.integer(floor(n_iter / 2))
  stopifnot(is.numeric(n_burnin), n_burnin >= 0L, n_burnin < n_iter)

  data <- as.data.frame(data)
  if (!all(vars %in% names(data))) {
    stop("Variables not found in data: ",
         paste(setdiff(vars, names(data)), collapse = ", "), call. = FALSE)
  }
  .ido_check_col(id, "id", data)
  .ido_check_col(day, "day", data)
  .ido_check_col(beep, "beep", data)
  data <- .ido_keep(data, id, min_obs, subject)
  .ido_check_numeric_vars(data, vars)

  p <- length(vars)
  # Reuse fit_graphical_var's data preparation (scale, within-centre, lag pairs).
  ts <- .gvar_tsdata(data, vars, id, day, beep, scale, center_within,
                     delete_missings = TRUE)
  Y <- ts$data_c              # n x p current
  X <- ts$data_l              # n x (p+1) intercept + lag
  n <- nrow(Y)
  # The residual covariance draw is IW(., n - (p+1)); a proper, full-rank draw
  # needs n - (p+1) >= p, i.e. n >= 2p + 1 lag pairs.
  if (n < 2L * p + 1L) {
    stop("Too few lag pairs (", n, ") for ", p, " variables; the residual ",
         "covariance needs at least ", 2L * p + 1L, ".", call. = FALSE)
  }

  if (verbose) message("Running ", n_chains, " chain(s) x ", n_iter,
                       " iterations (Bayesian VAR, n = ", n, ") ...")
  chains <- lapply(seq_len(n_chains), function(c_i)
    .varb_gibbs(X, Y, p, n_iter, n_burnin, thin,
                seed = if (is.null(seed)) NULL else seed + c_i))

  post <- .mlvb_pool_var(chains)     # $B (p x p x m), $S (p x p x m), $beta (q x p x m)
  psr  <- .varb_psr(chains)
  summ <- .varb_summaries(post, vars, p)

  beta_med <- summ$beta_med          # p x (p+1) [outcome, intercept+predictor]
  temporal <- summ$B_med             # p x p [outcome, predictor]
  Sigma    <- summ$S_med
  kappa    <- .mlvb_solve(Sigma)
  dimnames(kappa) <- list(vars, vars)
  pcc <- .gvar_compute_pcc(kappa)
  pdc <- .gvar_compute_pdc(beta_med, kappa)
  dimnames(pcc) <- dimnames(pdc) <- list(vars, vars)

  model <- list(
    beta = beta_med, temporal = temporal, kappa = kappa,
    Sigma = Sigma, PCC = pcc, PDC = pdc, contemporaneous = pcc,
    labels = vars, n_obs = n, coefs = summ$coefs,
    posterior = post, psr = psr,
    max_psr = if (any(is.finite(psr))) max(psr[is.finite(psr)]) else NA_real_,
    mcmc = list(n_iter = n_iter, n_burnin = n_burnin, n_chains = n_chains,
                thin = thin, n_draws = dim(post$B)[3]),
    estimator = "bayes"
  )
  .ido_group_result(
    "var_bayes_result",
    list(temporal = .ido_wrap(t(temporal), method = "relative", directed = TRUE),
         contemporaneous = .ido_wrap(pcc, method = "co_occurrence",
                                     directed = FALSE)),
    model)
}

# ---- One Gibbs chain (exact NIW two-block sampler) ---------------------------

#' @noRd
.varb_gibbs <- function(X, Y, p, n_iter, n_burnin, thin, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  n <- nrow(Y); q <- ncol(X)
  XtXinv <- .mlvb_solve(crossprod(X))
  Bfull_hat <- XtXinv %*% crossprod(X, Y)          # q x p (incl intercept row)
  cholXtXinv <- t(chol(XtXinv))
  Bf <- Bfull_hat; Sig <- stats::cov(Y - X %*% Bf)

  keep_it <- seq(n_burnin + 1L, n_iter, by = thin)
  m <- length(keep_it)
  out <- list(B = array(0, c(p, p, m)), S = array(0, c(p, p, m)),
              beta = array(0, c(p, q, m)))
  ki <- 0L
  for (it in seq_len(n_iter)) {
    E <- Y - X %*% Bf
    Sig <- .mlvb_riwish(n - (p + 1L), crossprod(E))         # Sigma | B
    Z <- matrix(stats::rnorm(q * p), q, p)
    Bf <- Bfull_hat + cholXtXinv %*% Z %*% chol(Sig)        # B | Sigma
    if (it %in% keep_it) {
      ki <- ki + 1L
      out$B[, , ki] <- t(Bf[-1L, , drop = FALSE])          # [outcome, predictor]
      out$S[, , ki] <- Sig
      out$beta[, , ki] <- t(Bf)                             # [outcome, intercept+pred]
    }
  }
  out
}

#' @noRd
.mlvb_pool_var <- function(chains) {
  cat3 <- function(slot) {
    arrs <- lapply(chains, `[[`, slot); d <- dim(arrs[[1]])
    array(unlist(arrs), c(d[1], d[2],
                          sum(vapply(arrs, function(a) dim(a)[3], integer(1)))))
  }
  list(B = cat3("B"), S = cat3("S"), beta = cat3("beta"))
}

#' @noRd
.varb_psr <- function(chains) {
  scal <- function(ch) cbind(
    matrix(aperm(ch$B, c(3, 1, 2)), nrow = dim(ch$B)[3]),
    matrix(aperm(ch$S, c(3, 1, 2)), nrow = dim(ch$S)[3]))
  mats <- lapply(chains, scal)
  M <- length(mats); if (M < 2L) return(NA_real_)
  nkeep <- nrow(mats[[1]])
  means <- vapply(mats, colMeans, numeric(ncol(mats[[1]])))
  vars  <- vapply(mats, function(x) apply(x, 2, stats::var),
                  numeric(ncol(mats[[1]])))
  Bv <- nkeep * apply(means, 1, stats::var); Wv <- rowMeans(vars)
  varhat <- ((nkeep - 1) / nkeep) * Wv + Bv / nkeep
  psr <- sqrt(varhat / Wv); psr[is.finite(psr)]
}

#' @noRd
.varb_summaries <- function(post, vars, p) {
  med <- function(a) apply(a, c(1, 2), stats::median)
  B_med <- med(post$B); S_med <- med(post$S); beta_med <- med(post$beta)
  dimnames(B_med) <- dimnames(S_med) <- list(vars, vars)
  q <- function(a, pr) apply(a, c(1, 2), stats::quantile, probs = pr,
                             names = FALSE)
  Blo <- q(post$B, 0.025); Bhi <- q(post$B, 0.975)
  Bsd <- apply(post$B, c(1, 2), stats::sd)
  ptail <- apply(post$B, c(1, 2), function(x) { pg <- mean(x > 0); min(pg, 1 - pg) })
  idx <- expand.grid(row = seq_len(p), col = seq_len(p))
  coefs <- data.frame(
    outcome = vars[idx$row], predictor = vars[idx$col],
    estimate = B_med[cbind(idx$row, idx$col)],
    posterior_sd = Bsd[cbind(idx$row, idx$col)],
    ci_lower = Blo[cbind(idx$row, idx$col)],
    ci_upper = Bhi[cbind(idx$row, idx$col)],
    p = ptail[cbind(idx$row, idx$col)], stringsAsFactors = FALSE)
  coefs$significant <- coefs$ci_lower > 0 | coefs$ci_upper < 0
  coefs <- coefs[order(idx$row, idx$col), ]; rownames(coefs) <- NULL
  list(B_med = B_med, S_med = S_med, beta_med = beta_med, coefs = coefs)
}

# ---- S3 methods --------------------------------------------------------------

#' @export
`$.var_bayes_result` <- function(x, name) .ido_result_dollar(x, name)

#' @rdname coefs
#' @export
coefs.var_bayes_result <- function(x, ...) attr(x, "model")$coefs

#' Coerce a var_bayes_result to plottable netobjects
#' @param x A `var_bayes_result`.
#' @param ... Ignored.
#' @return A `netobject_group` with `temporal` (directed) and
#'   `contemporaneous` (undirected) netobjects.
#' @export
as_netobject.var_bayes_result <- function(x, ...) .ido_network_group(x)

#' Print method for var_bayes_result
#' @param x A `var_bayes_result`.
#' @param digits Digits for printed networks.
#' @param ... Unused.
#' @return Invisibly `x`.
#' @export
print.var_bayes_result <- function(x, digits = 2, ...) {
  m <- attr(x, "model")
  d <- length(m$labels)
  n_sig <- sum(m$coefs$significant, na.rm = TRUE)
  cat("Bayesian VAR(1) result (unregularized, Mplus-targeted)\n")
  cat(sprintf("  Variables:    %d (%s)\n", d, paste(m$labels, collapse = ", ")))
  cat(sprintf("  Observations: %d\n", m$n_obs))
  cat(sprintf("  MCMC: %d chains x %d iter, %d draws | max PSR = %.3f\n",
              m$mcmc$n_chains, m$mcmc$n_iter, m$mcmc$n_draws, m$max_psr))
  cat(sprintf("  Temporal 95%% CIs excluding 0: %d / %d\n", n_sig, nrow(m$coefs)))
  .ido_print_networks(x, digits = digits)
  cat("\n  coefs(x) | matrices(x) | edges(x) | nodes(x) | summary(x)\n")
  invisible(x)
}

#' Summary method for var_bayes_result
#' @param object A `var_bayes_result`.
#' @param ... Unused.
#' @return A tidy per-network metrics `data.frame`.
#' @export
summary.var_bayes_result <- function(object, ...) {
  .tidy_over_group(as_netobject(object), .net_metrics)
}
