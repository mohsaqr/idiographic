# Native estimators and optional external backends.
#
# Every fitted model is a plain list carrying at least `type` (used by
# .idio_ml_predict) and `coef` (a named numeric vector, used by coefs() and
# importance()). Predictors are always standardized on the *training* rows and
# the same centering/scaling is applied to test rows, so coefficients from
# different models are on a comparable scale.

#' Models available for a task and estimator
#' @noRd
.idio_ml_models <- function(model, task, estimator = "native") {
  # `model = "all"` means "everything usable here", so a backend that is not
  # installed is skipped rather than turned into an error the caller did not
  # ask for.
  if (identical(model, "all")) return(.idio_registry_available(task, estimator))
  if (!(is.character(model) && length(model) >= 1L)) {
    stop("`model` must be 'all' or a character vector.", call. = FALSE)
  }
  # Validate through the registry so the message can say where a model lives,
  # rather than only that it is absent from one backend's list.
  invisible(lapply(unique(model), function(m) {
    .idio_resolve_model(m, task, estimator)
  }))
  unique(model)
}

#' Load an optional backend, offering to install it once when interactive
#' @noRd
.idio_require <- function(pkg, estimator) {
  if (requireNamespace(pkg, quietly = TRUE)) return(invisible(TRUE))
  if (interactive()) {
    ans <- readline(sprintf(
      "Package '%s' is needed for estimator = \"%s\".\nInstall it now? [y/N] ",
      pkg, estimator))
    if (tolower(trimws(ans)) %in% c("y", "yes")) {
      utils::install.packages(pkg)
      if (requireNamespace(pkg, quietly = TRUE)) return(invisible(TRUE))
    }
  }
  stop("Estimator \"", estimator, "\" needs the '", pkg,
       "' package. Install it with install.packages(\"", pkg, "\").",
       call. = FALSE)
}

# ---------------------------------------------------------------- scaling ----

.idio_scale <- function(X) {
  center <- colMeans(X, na.rm = TRUE)
  scale <- apply(X, 2L, stats::sd, na.rm = TRUE)
  scale[!is.finite(scale) | scale == 0] <- 1
  center[!is.finite(center)] <- 0
  list(center = center, scale = scale)
}

.idio_apply_scale <- function(X, pars) {
  sweep(sweep(X, 2L, pars$center, "-"), 2L, pars$scale, "/")
}

# ------------------------------------------------------------------- fit ------

#' Fit one native or external model on standardized predictors
#' @noRd
.idio_fit_native <- function(Xs, yv, x, model, task, control) {
  if (model %in% c("mean", "majority")) {
    value <- mean(yv)
    label <- if (task == "regression") "mean" else "probability"
    return(list(type = "constant", value = value,
                coef = stats::setNames(value, label)))
  }
  if (model == "knn") {
    return(list(type = "knn", x_train = Xs, y_train = yv, k = control$k,
                coef = stats::setNames(as.numeric(control$k), "k")))
  }
  if (model == "tree") {
    return(c(list(type = "tree"), .idio_tree_stump(Xs, yv, x)))
  }
  if (model == "pcr") {
    return(.idio_fit_pcr(Xs, yv, x, control))
  }
  if (model == "boost") {
    return(.idio_fit_boost(Xs, yv, x, task, control))
  }
  if (model == "spline") {
    return(.idio_fit_spline(Xs, yv, x, task, control))
  }
  if (model == "lda") {
    return(.idio_fit_lda(Xs, yv, x))
  }
  if (model == "bayes") {
    return(.idio_fit_nb(Xs, yv, x))
  }

  # Linear family: linear/logistic are the unpenalized limits of the
  # elastic net, so they all route through one solver.
  family <- if (task == "regression") "gaussian" else "binomial"
  spec <- switch(model,
    linear   = list(lambda = 0, alpha = 0),
    logistic = list(lambda = 0, alpha = 0),
    ridge    = list(lambda = control$lambda, alpha = 0),
    lasso    = list(lambda = control$lambda, alpha = 1),
    elastic  = list(lambda = control$lambda, alpha = control$alpha),
    stop("Unsupported native model: ", model, call. = FALSE)
  )
  beta <- .idio_enet_fit(Xs, yv, spec$lambda, spec$alpha, family)
  names(beta) <- c("(Intercept)", x)
  list(type = if (family == "gaussian") "linear" else "logit", beta = beta,
       coef = beta)
}

# ------------------------------------------------------- elastic-net core ----

#' Elastic-net fit via FISTA (and IRLS for the binomial case)
#'
#' Minimises 1/2 ||y - Xb||^2 + lambda * (alpha*||b||_1 + (1-alpha)/2*||b||^2).
#' With `alpha = 0` and `lambda = 0` this is ordinary least squares, so the
#' unpenalized models fall out of the same solver.
#'
#' Proximal gradient (rather than coordinate descent) keeps every iteration a
#' whole-matrix operation instead of a per-coefficient scan.
#'
#' @noRd
.idio_enet_fit <- function(Xs, y, lambda, alpha, family = "gaussian") {
  if (family == "gaussian") {
    # Closed form when there is no L1 term: exact and fast.
    if (alpha == 0 || lambda == 0) {
      return(.idio_ridge_beta(cbind(1, Xs), y, lambda))
    }
    b0 <- mean(y)
    beta <- .idio_fista(Xs, y - b0, w = NULL, lambda = lambda, alpha = alpha)
    return(c(b0, beta))
  }

  # Binomial: IRLS outer loop, penalized weighted least squares inner.
  p <- ncol(Xs)
  b0 <- stats::qlogis(min(max(mean(y), 0.01), 0.99))
  beta <- rep(0, p)
  iter <- 0L
  repeat {
    iter <- iter + 1L
    eta <- b0 + as.numeric(Xs %*% beta)
    mu <- stats::plogis(eta)
    w <- pmax(mu * (1 - mu), 1e-5)
    z <- eta + (y - mu) / w
    b0_new <- sum(w * (z - as.numeric(Xs %*% beta))) / sum(w)
    beta_new <- if (alpha == 0 || lambda == 0) {
      .idio_wridge_beta(Xs, z - b0_new, w, lambda)
    } else {
      .idio_fista(Xs, z - b0_new, w = w, lambda = lambda, alpha = alpha)
    }
    delta <- max(abs(c(b0_new, beta_new) - c(b0, beta)))
    b0 <- b0_new
    beta <- beta_new
    if (!is.finite(delta) || delta < 1e-6 || iter >= 50L) break
  }
  c(b0, beta)
}

#' One FISTA solve of a (weighted) elastic-net problem, intercept excluded
#' @noRd
.idio_fista <- function(X, y, w = NULL, lambda, alpha, maxit = 500L,
                        tol = 1e-8) {
  n <- nrow(X)
  p <- ncol(X)
  wv <- if (is.null(w)) rep(1, n) else w
  XtW <- t(X * wv)
  step <- 1 / max(.idio_lipschitz(X, wv), .Machine$double.eps)
  l1 <- step * lambda * alpha
  shrink <- 1 / (1 + step * lambda * (1 - alpha))

  beta <- rep(0, p)
  zeta <- beta
  t_k <- 1
  iter <- 0L
  repeat {
    iter <- iter + 1L
    grad <- as.numeric(XtW %*% (as.numeric(X %*% zeta) - y))
    prox <- .idio_soft_threshold(zeta - step * grad, l1) * shrink
    t_next <- (1 + sqrt(1 + 4 * t_k^2)) / 2
    zeta <- prox + ((t_k - 1) / t_next) * (prox - beta)
    delta <- max(abs(prox - beta))
    beta <- prox
    t_k <- t_next
    if (!is.finite(delta) || delta < tol || iter >= maxit) break
  }
  beta
}

.idio_lipschitz <- function(X, w) {
  A <- crossprod(X * sqrt(w))
  max(abs(eigen(A, symmetric = TRUE, only.values = TRUE)$values))
}

.idio_soft_threshold <- function(z, g) {
  sign(z) * pmax(abs(z) - g, 0)
}

.idio_ridge_beta <- function(X, y, lambda) {
  pen <- diag(ncol(X))
  pen[1L, 1L] <- 0
  as.numeric(solve(crossprod(X) + lambda * pen, crossprod(X, y)))
}

.idio_wridge_beta <- function(Xs, y, w, lambda) {
  A <- crossprod(Xs * sqrt(w)) + lambda * diag(ncol(Xs))
  as.numeric(solve(A, crossprod(Xs, w * y)))
}

# ------------------------------------------------------------ other natives ---

.idio_fit_pcr <- function(Xs, yv, x, control) {
  ncomp <- max(1L, min(as.integer(control$ncomp), ncol(Xs), nrow(Xs) - 1L))
  sv <- svd(Xs)
  V <- sv$v[, seq_len(ncomp), drop = FALSE]
  scores <- Xs %*% V
  b0 <- mean(yv)
  gamma <- as.numeric(solve(crossprod(scores) +
                              diag(1e-8, ncomp), crossprod(scores, yv - b0)))
  beta <- as.numeric(V %*% gamma)
  full <- c(b0, beta)
  names(full) <- c("(Intercept)", x)
  list(type = "linear", beta = full, coef = full, ncomp = ncomp)
}

.idio_fit_lda <- function(Xs, yv, x) {
  if (length(unique(yv)) < 2L) {
    stop("LDA needs both outcome classes in the training rows.", call. = FALSE)
  }
  mu1 <- colMeans(Xs[yv == 1L, , drop = FALSE])
  mu0 <- colMeans(Xs[yv == 0L, , drop = FALSE])
  sigma <- stats::cov(Xs) + diag(1e-6, ncol(Xs))
  w <- as.numeric(solve(sigma, mu1 - mu0))
  prior <- mean(yv)
  b0 <- as.numeric(-0.5 * crossprod(mu1 + mu0, w)) +
    log(prior / (1 - prior))
  beta <- c(b0, w)
  names(beta) <- c("(Intercept)", x)
  list(type = "logit", beta = beta, coef = beta)
}

.idio_fit_nb <- function(Xs, yv, x) {
  if (length(unique(yv)) < 2L) {
    stop("Naive Bayes needs both outcome classes in the training rows.",
         call. = FALSE)
  }
  stats_for <- function(cls) {
    sub <- Xs[yv == cls, , drop = FALSE]
    sd <- apply(sub, 2L, stats::sd)
    sd[!is.finite(sd) | sd < 1e-6] <- 1e-6
    list(mean = colMeans(sub), sd = sd)
  }
  s1 <- stats_for(1L)
  s0 <- stats_for(0L)
  # Standardized mean difference is the natural per-variable effect here, and
  # gives importance() something meaningful to rank.
  pooled <- sqrt((s1$sd^2 + s0$sd^2) / 2)
  coef <- (s1$mean - s0$mean) / pooled
  names(coef) <- x
  list(type = "naive_bayes", s1 = s1, s0 = s0, prior = mean(yv), coef = coef)
}

.idio_tree_stump <- function(X, y, x, min_leaf = 1L) {
  candidates <- lapply(seq_along(x), function(j) {
    vals <- sort(unique(X[, j]))
    if (length(vals) < 2L) return(NULL)
    cuts <- (utils::head(vals, -1L) + utils::tail(vals, -1L)) / 2
    if (length(cuts) > 50L) {
      cuts <- unique(stats::quantile(cuts, seq(0, 1, length.out = 50),
                                     names = FALSE))
    }
    scores <- vapply(cuts, function(cut) {
      left_idx <- X[, j] <= cut
      # Without a floor on leaf size the best split is often the one that
      # isolates two or three extreme points: it reduces squared error most
      # while describing nothing. That is fatal for boosting, where the same
      # degenerate split then wins every round and the ensemble never moves.
      if (sum(left_idx) < min_leaf || sum(!left_idx) < min_leaf) return(Inf)
      pred <- ifelse(left_idx, mean(y[left_idx]), mean(y[!left_idx]))
      mean((y - pred)^2)
    }, numeric(1))
    best <- which.min(scores)
    if (!is.finite(scores[best])) return(NULL)
    left_idx <- X[, j] <= cuts[best]
    list(score = scores[best], variable = x[j], threshold = cuts[best],
         left = mean(y[left_idx]), right = mean(y[!left_idx]))
  })
  candidates <- candidates[!vapply(candidates, is.null, logical(1))]
  if (!length(candidates)) {
    stop("No usable split for the tree model.", call. = FALSE)
  }
  best <- candidates[[which.min(vapply(candidates, `[[`, numeric(1), "score"))]]
  coef <- c(best$threshold, best$left, best$right)
  names(coef) <- c(paste0("threshold:", best$variable), "left", "right")
  list(variable = best$variable, threshold = best$threshold, left = best$left,
       right = best$right, coef = coef)
}

# ----------------------------------------------------------- external fits ----

.idio_fit_glmnet <- function(Xs, yv, x, model, task, control) {
  .idio_require("glmnet", "glmnet")
  if (ncol(Xs) < 2L) {
    stop("glmnet needs at least two predictors.", call. = FALSE)
  }
  alpha <- switch(model, ridge = 0, lasso = 1, elastic = control$alpha)
  family <- if (task == "regression") "gaussian" else "binomial"
  fit <- glmnet::glmnet(Xs, yv, family = family, alpha = alpha,
                        lambda = max(control$lambda, 1e-4),
                        standardize = FALSE)
  beta <- as.numeric(as.matrix(stats::coef(fit)))
  names(beta) <- c("(Intercept)", x)
  list(type = "glmnet", fit = fit, coef = beta)
}

.idio_fit_ranger <- function(Xs, yv, x, model, task, control) {
  .idio_require("ranger", "ranger")
  df <- as.data.frame(Xs)
  names(df) <- x
  classification <- task == "classification"
  df$.y <- if (classification) factor(yv, levels = c(0L, 1L)) else yv
  fit <- ranger::ranger(
    dependent.variable.name = ".y", data = df,
    num.trees = control$num_trees,
    mtry = max(1L, min(as.integer(control$mtry), length(x))),
    probability = classification, importance = "impurity",
    respect.unordered.factors = "order", verbose = FALSE
  )
  coef <- fit$variable.importance
  list(type = "ranger", fit = fit, classification = classification,
       vars = x, coef = coef)
}

.idio_fit_e1071 <- function(Xs, yv, x, model, task, control) {
  .idio_require("e1071", "e1071")
  df <- as.data.frame(Xs)
  names(df) <- x
  classification <- task == "classification"
  if (model == "bayes") {
    fit <- e1071::naiveBayes(x = df, y = factor(yv, levels = c(0L, 1L)))
    return(list(type = "e1071_bayes", fit = fit, vars = x,
                coef = numeric(0)))
  }
  target <- if (classification) factor(yv, levels = c(0L, 1L)) else yv
  fit <- e1071::svm(x = df, y = target, cost = control$cost,
                    kernel = "radial", probability = classification,
                    scale = FALSE)
  list(type = "e1071_svm", fit = fit, classification = classification,
       vars = x, coef = numeric(0))
}

# --------------------------------------------------------------- predict ------

.idio_knn_predict <- function(x_new, x_train, y_train, k) {
  k <- min(k, nrow(x_train))
  vapply(seq_len(nrow(x_new)), function(i) {
    d <- colSums((t(x_train) - x_new[i, ])^2)
    mean(y_train[order(d)[seq_len(k)]])
  }, numeric(1))
}

.idio_nb_predict <- function(Xs, fit) {
  loglik <- function(s) {
    dens <- vapply(seq_len(ncol(Xs)), function(j) {
      stats::dnorm(Xs[, j], mean = s$mean[j], sd = s$sd[j], log = TRUE)
    }, numeric(nrow(Xs)))
    rowSums(matrix(dens, nrow = nrow(Xs)))
  }
  delta <- (loglik(fit$s1) + log(fit$prior)) -
    (loglik(fit$s0) + log(1 - fit$prior))
  stats::plogis(delta)
}

.idio_ranger_predict <- function(Xs, fit) {
  df <- as.data.frame(Xs)
  names(df) <- fit$vars
  pred <- stats::predict(fit$fit, data = df)$predictions
  if (fit$classification) as.numeric(pred[, "1"]) else as.numeric(pred)
}

.idio_svm_predict <- function(Xs, fit) {
  df <- as.data.frame(Xs)
  names(df) <- fit$vars
  if (!fit$classification) {
    return(as.numeric(stats::predict(fit$fit, df)))
  }
  pred <- stats::predict(fit$fit, df, probability = TRUE)
  as.numeric(attr(pred, "probabilities")[, "1"])
}

.idio_e1071_nb_predict <- function(Xs, fit) {
  df <- as.data.frame(Xs)
  names(df) <- fit$vars
  as.numeric(stats::predict(fit$fit, df, type = "raw")[, "1"])
}
