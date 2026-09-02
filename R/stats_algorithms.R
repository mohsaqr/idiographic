# Fit and predict for every registered algorithm.
#
# The contract every branch must honour:
#   * it receives STANDARDIZED predictors `Xs` (columns centred and scaled on
#     the training rows) and never re-scales them;
#   * it returns a plain list with a `type` used by .idio_ml_predict(), and a
#     `coef` named numeric vector (possibly numeric(0)) used by coefs();
#   * for classification it predicts P(positive class), never a hard label.
#
# Everything external is wrapped so the caller never handles a backend object.

#' Run an expression without letting a backend print to the console
#'
#' Some backends report progress with `cat()` rather than through the
#' condition system, so `suppressMessages()` alone does not silence them.
#'
#' @noRd
.idio_quietly <- function(expr) {
  sink(tempfile())
  on.exit(sink(), add = TRUE)
  suppressMessages(suppressWarnings(expr))
}

# ------------------------------------------------------------------ fit ----

#' Fit one model, whichever backend provides it
#' @noRd
.idio_ml_fit <- function(train, y, x, model, task, control,
                         estimator = "auto") {
  X <- as.matrix(train[x])
  pars <- .idio_scale(X)
  Xs <- .idio_apply_scale(X, pars)
  yv <- if (task == "regression") {
    as.numeric(train[[y]])
  } else {
    as.integer(train[[y]])
  }
  backend <- .idio_resolve_model(model, task, estimator)

  fit <- switch(backend$estimator,
    native   = .idio_fit_native(Xs, yv, x, model, task, control),
    stats    = .idio_fit_stats(Xs, yv, x, model, task, control),
    rpart    = .idio_fit_rpart(Xs, yv, x, task, control),
    nnet     = .idio_fit_nnet(Xs, yv, x, model, task, control),
    mgcv     = .idio_fit_mgcv(Xs, yv, x, task, control),
    MASS     = .idio_fit_mass(Xs, yv, x, model, task),
    glmnet   = .idio_fit_glmnet(Xs, yv, x, model, task, control),
    ranger   = .idio_fit_ranger(Xs, yv, x, model, task, control),
    e1071    = .idio_fit_e1071(Xs, yv, x, model, task, control),
    xgboost  = .idio_fit_xgboost(Xs, yv, x, task, control),
    kernlab  = .idio_fit_kernlab(Xs, yv, x, model, task, control),
    pls      = .idio_fit_pls(Xs, yv, x, control),
    partykit = .idio_fit_partykit(Xs, yv, x, model, task, control),
    quantreg = .idio_fit_quantreg(Xs, yv, x, control),
    randomForest = .idio_fit_rf(Xs, yv, x, task, control),
    mboost   = .idio_fit_mboost(Xs, yv, x, task, control),
    stop("Unknown estimator: ", backend$estimator, call. = FALSE)
  )
  fit$scale <- pars
  fit$task <- fit$task %||% task
  fit$estimator <- backend$estimator
  fit
}

#' A data frame of standardized predictors, named consistently
#'
#' Every backend that wants a formula gets its predictors through here, so the
#' names used at fit time and at predict time cannot drift apart.
#'
#' @noRd
.idio_frame <- function(Xs, x) {
  out <- as.data.frame(Xs)
  names(out) <- make.names(x, unique = TRUE)
  out
}

.idio_formula_all <- function(names_x) {
  stats::as.formula(paste(".idio_y ~", paste(names_x, collapse = " + ")))
}

# ------------------------------------------------- hand-written additions ----

#' Gradient-boosted stumps
#'
#' Boosting a sequence of one-split stumps onto the residual gives a flexible
#' ADDITIVE model: each stump uses a single predictor, so the ensemble is a sum
#' of one-dimensional step functions. It captures nonlinearity well and
#' interactions NOT AT ALL -- a depth-1 tree cannot represent `x1 * x2`, and no
#' number of rounds changes that. On data generated purely from an interaction
#' it therefore lands near R-squared 0, correctly. Reach for `xgboost` (depth 3),
#' `cart`, `ctree` or `mob` when interactions are the point.
#'
#' Classification boosts on the logit scale.
#'
#' @noRd
.idio_fit_boost <- function(Xs, yv, x, task, control) {
  rounds <- max(1L, as.integer(control$rounds))
  rate <- control$learn_rate
  # Each split must describe a real share of the data, not a few outliers.
  min_leaf <- max(5L, ceiling(0.05 * nrow(Xs)))
  if (task == "regression") {
    prediction <- rep(mean(yv), length(yv))
    target <- yv
  } else {
    # Boost the log-odds; the initial guess is the base rate.
    rate_0 <- min(max(mean(yv), 1e-6), 1 - 1e-6)
    prediction <- rep(log(rate_0 / (1 - rate_0)), length(yv))
    target <- yv
  }
  stumps <- vector("list", rounds)
  kept <- 0L
  for (round in seq_len(rounds)) {
    residual <- if (task == "regression") {
      target - prediction
    } else {
      target - stats::plogis(prediction)
    }
    if (stats::sd(residual) < 1e-10) break
    stump <- tryCatch(.idio_tree_stump(Xs, residual, x, min_leaf = min_leaf),
                      error = function(e) NULL)
    if (is.null(stump)) break
    step <- .idio_stump_predict(stump, Xs)
    prediction <- prediction + rate * step
    kept <- kept + 1L
    stumps[[kept]] <- stump
  }
  if (!kept) {
    value <- if (task == "regression") mean(yv) else mean(yv)
    return(list(type = "constant", value = value,
                coef = stats::setNames(value, "mean")))
  }
  list(type = "boost", stumps = stumps[seq_len(kept)], rate = rate,
       intercept = if (task == "regression") mean(yv) else {
         stats::qlogis(min(max(mean(yv), 1e-6), 1 - 1e-6))
       },
       coef = .idio_boost_importance(stumps[seq_len(kept)], x, rate))
}

#' One stump's prediction on a design
#' @noRd
.idio_stump_predict <- function(stump, Xs) {
  column <- match(stump$variable, colnames(Xs))
  ifelse(Xs[, column] <= stump$threshold, stump$left, stump$right)
}

#' Total absolute step each predictor contributed, as a coefficient stand-in
#' @noRd
.idio_boost_importance <- function(stumps, x, rate) {
  gain <- stats::setNames(numeric(length(x)), x)
  for (stump in stumps) {
    gain[stump$variable] <- gain[stump$variable] +
      rate * abs(stump$right - stump$left)
  }
  gain
}

#' Natural splines fed into the existing penalized solver
#'
#' Smooth nonlinearity without a new dependency: expand every predictor into a
#' natural-spline basis and hand the result to the same FISTA solver the linear
#' models use, so the fit stays penalized and the predict path stays shared.
#'
#' @noRd
.idio_fit_spline <- function(Xs, yv, x, task, control) {
  df <- max(2L, as.integer(control$df))
  bases <- lapply(seq_along(x), function(j) {
    column <- Xs[, j]
    if (length(unique(column)) <= df) return(matrix(column, ncol = 1L))
    tryCatch(splines::ns(column, df = df),
             error = function(e) matrix(column, ncol = 1L))
  })
  basis <- do.call(cbind, lapply(bases, function(b) as.matrix(b)))
  colnames(basis) <- paste0(rep(x, vapply(bases, ncol, integer(1))), "_s",
                            unlist(lapply(bases, function(b) seq_len(ncol(b)))))
  family <- if (task == "regression") "gaussian" else "binomial"
  beta <- .idio_enet_fit(basis, yv, control$lambda, 0, family)
  names(beta) <- c("(Intercept)", colnames(basis))
  list(type = "spline", beta = beta, bases = bases, df = df,
       vars = x, coef = beta)
}

#' Rebuild the spline basis for new rows, using the training knots
#' @noRd
.idio_spline_basis <- function(fit, Xs) {
  parts <- lapply(seq_along(fit$vars), function(j) {
    basis <- fit$bases[[j]]
    column <- Xs[, j]
    if (is.null(attr(basis, "knots"))) return(matrix(column, ncol = 1L))
    as.matrix(stats::predict(basis, column))
  })
  do.call(cbind, parts)
}

# -------------------------------------------------------- base R backends ----

#' loess, projection pursuit and isotonic regression
#' @noRd
.idio_fit_stats <- function(Xs, yv, x, model, task, control) {
  frame <- .idio_frame(Xs, x)
  frame$.idio_y <- yv
  if (model == "loess") {
    # loess struggles beyond a handful of predictors, which is a property of
    # the method rather than of this wrapper.
    fit <- stats::loess(.idio_formula_all(names(frame)[seq_along(x)]),
                        data = frame, span = control$span,
                        control = stats::loess.control(surface = "direct"))
    return(list(type = "stats_loess", fit = fit, vars = names(frame)[seq_along(x)],
                coef = numeric(0)))
  }
  if (model == "ppr") {
    terms <- max(1L, min(as.integer(control$nterms), length(x)))
    fit <- stats::ppr(.idio_formula_all(names(frame)[seq_along(x)]),
                      data = frame, nterms = terms)
    return(list(type = "stats_ppr", fit = fit,
                vars = names(frame)[seq_along(x)], coef = numeric(0)))
  }
  # Isotonic regression is univariate by construction, so it is fitted on the
  # single predictor most correlated with the outcome and says so.
  strength <- abs(apply(Xs, 2L, function(z) {
    if (stats::sd(z) == 0) 0 else stats::cor(z, yv)
  }))
  j <- which.max(strength)
  ordering <- order(Xs[, j])
  fit <- stats::isoreg(Xs[ordering, j], yv[ordering])
  list(type = "stats_isotonic", knots = fit$x, values = fit$yf, column = j,
       coef = stats::setNames(strength[j], x[j]))
}

# ------------------------------------------------ packages that ship with R ----

#' CART via rpart
#' @noRd
.idio_fit_rpart <- function(Xs, yv, x, task, control) {
  frame <- .idio_frame(Xs, x)
  frame$.idio_y <- if (task == "regression") yv else factor(yv, levels = c(0L, 1L))
  fit <- rpart::rpart(.idio_formula_all(names(frame)[seq_along(x)]),
                      data = frame,
                      method = if (task == "regression") "anova" else "class",
                      control = rpart::rpart.control(cp = control$cp,
                                                     minsplit = 10L))
  importance <- fit$variable.importance
  coef <- stats::setNames(numeric(length(x)), names(frame)[seq_along(x)])
  if (!is.null(importance)) coef[names(importance)] <- importance
  list(type = "rpart", fit = fit, vars = names(frame)[seq_along(x)],
       coef = stats::setNames(as.numeric(coef), x))
}

#' Single-hidden-layer neural net, and multinomial logistic, via nnet
#' @noRd
.idio_fit_nnet <- function(Xs, yv, x, model, task, control) {
  frame <- .idio_frame(Xs, x)
  vars <- names(frame)[seq_along(x)]
  if (model == "multinom") {
    frame$.idio_y <- factor(yv)
    invisible(utils::capture.output(
      model_fit <- nnet::multinom(.idio_formula_all(vars), data = frame,
                                  decay = control$decay, trace = FALSE)))
    return(list(type = "nnet_multinom", fit = model_fit, vars = vars,
                coef = numeric(0)))
  }
  frame$.idio_y <- yv
  fit <- nnet::nnet(.idio_formula_all(vars), data = frame,
                    size = max(1L, as.integer(control$size)),
                    decay = control$decay, maxit = 300L, trace = FALSE,
                    linout = task == "regression")
  list(type = "nnet_mlp", fit = fit, vars = vars, coef = numeric(0))
}

#' GAM via mgcv, with a smooth on every predictor that can carry one
#' @noRd
.idio_fit_mgcv <- function(Xs, yv, x, task, control) {
  frame <- .idio_frame(Xs, x)
  vars <- names(frame)[seq_along(x)]
  frame$.idio_y <- yv
  basis <- max(3L, as.integer(control$k))
  # A predictor with too few distinct values cannot support a smooth, so it
  # enters linearly instead of making the whole fit fail.
  terms <- vapply(seq_along(vars), function(j) {
    if (length(unique(Xs[, j])) > basis) {
      sprintf("s(%s, k = %d)", vars[j], basis)
    } else {
      vars[j]
    }
  }, character(1))
  form <- stats::as.formula(paste(".idio_y ~", paste(terms, collapse = " + ")))
  fit <- mgcv::gam(form, data = frame,
                   family = if (task == "regression") stats::gaussian() else
                     stats::binomial())
  list(type = "mgcv_gam", fit = fit, vars = vars, coef = numeric(0))
}

#' QDA and proportional-odds ordinal regression via MASS
#' @noRd
.idio_fit_mass <- function(Xs, yv, x, model, task) {
  frame <- .idio_frame(Xs, x)
  vars <- names(frame)[seq_along(x)]
  frame$.idio_y <- factor(yv)
  if (model == "qda") {
    fit <- MASS::qda(.idio_formula_all(vars), data = frame)
    return(list(type = "mass_qda", fit = fit, vars = vars, coef = numeric(0)))
  }
  fit <- MASS::polr(.idio_formula_all(vars), data = frame, Hess = TRUE)
  list(type = "mass_polr", fit = fit, vars = vars,
       coef = stats::setNames(stats::coef(fit), x[seq_along(stats::coef(fit))]))
}

# ------------------------------------------------------ optional backends ----

.idio_fit_xgboost <- function(Xs, yv, x, task, control) {
  fit <- xgboost::xgboost(
    data = Xs, label = yv, nrounds = max(1L, as.integer(control$rounds)),
    eta = control$learn_rate, max_depth = 3L, verbose = 0L, nthread = 1L,
    objective = if (task == "regression") "reg:squarederror" else
      "binary:logistic")
  importance <- tryCatch(xgboost::xgb.importance(model = fit),
                         error = function(e) NULL)
  coef <- stats::setNames(numeric(length(x)), x)
  if (!is.null(importance) && nrow(importance)) {
    coef[importance$Feature] <- importance$Gain
  }
  list(type = "xgboost", fit = fit, coef = coef)
}

.idio_fit_kernlab <- function(Xs, yv, x, model, task, control) {
  if (model == "gp") {
    fit <- .idio_quietly(kernlab::gausspr(
      Xs, if (task == "regression") yv else factor(yv),
      variance.model = FALSE))
    return(list(type = "kernlab_gp", fit = fit, coef = numeric(0)))
  }
  fit <- .idio_quietly(kernlab::ksvm(
    Xs, if (task == "regression") yv else factor(yv),
    C = control$cost, prob.model = task != "regression"))
  list(type = "kernlab_svm", fit = fit, coef = numeric(0))
}

.idio_fit_pls <- function(Xs, yv, x, control) {
  frame <- data.frame(.idio_y = yv)
  frame$X <- Xs
  ncomp <- max(1L, min(as.integer(control$ncomp), ncol(Xs),
                       nrow(Xs) - 1L))
  fit <- pls::plsr(.idio_y ~ X, data = frame, ncomp = ncomp)
  loadings <- tryCatch(as.numeric(stats::coef(fit, ncomp = ncomp)),
                       error = function(e) numeric(0))
  list(type = "pls", fit = fit, ncomp = ncomp,
       coef = if (length(loadings) == length(x)) {
         stats::setNames(loadings, x)
       } else {
         numeric(0)
       })
}

.idio_fit_partykit <- function(Xs, yv, x, model, task, control) {
  frame <- .idio_frame(Xs, x)
  vars <- names(frame)[seq_along(x)]
  frame$.idio_y <- if (task == "regression") yv else factor(yv, levels = c(0L, 1L))
  if (model == "mob") {
    # A model-based tree needs a model to split: the outcome on the first
    # predictor, partitioned by the rest.
    form <- stats::as.formula(paste(".idio_y ~", vars[1L], "|",
                                    paste(vars[-1L], collapse = " + ")))
    if (length(vars) < 2L) {
      stop("\"mob\" needs at least two predictors: one for the model and one ",
           "to split on.", call. = FALSE)
    }
    fit <- partykit::lmtree(form, data = frame,
                            alpha = control$alpha_split)
    return(list(type = "partykit", fit = fit, vars = vars, coef = numeric(0)))
  }
  fit <- partykit::ctree(.idio_formula_all(vars), data = frame,
                         control = partykit::ctree_control(alpha = control$alpha_split))
  list(type = "partykit", fit = fit, vars = vars, coef = numeric(0))
}

.idio_fit_quantreg <- function(Xs, yv, x, control) {
  frame <- .idio_frame(Xs, x)
  vars <- names(frame)[seq_along(x)]
  frame$.idio_y <- yv
  fit <- quantreg::rq(.idio_formula_all(vars), data = frame, tau = control$tau)
  beta <- stats::coef(fit)
  names(beta) <- c("(Intercept)", x)
  list(type = "quantreg", fit = fit, vars = vars, coef = beta)
}

.idio_fit_rf <- function(Xs, yv, x, task, control) {
  mtry <- max(1L, min(as.integer(control$mtry %||% ceiling(ncol(Xs) / 3)),
                      ncol(Xs)))
  fit <- randomForest::randomForest(
    x = Xs, y = if (task == "regression") yv else factor(yv, levels = c(0L, 1L)),
    mtry = mtry, ntree = control$num_trees)
  importance <- tryCatch(randomForest::importance(fit)[, 1L],
                         error = function(e) NULL)
  list(type = "randomForest", fit = fit,
       coef = if (length(importance) == length(x)) {
         stats::setNames(as.numeric(importance), x)
       } else {
         numeric(0)
       })
}

.idio_fit_mboost <- function(Xs, yv, x, task, control) {
  frame <- .idio_frame(Xs, x)
  vars <- names(frame)[seq_along(x)]
  frame$.idio_y <- if (task == "regression") yv else factor(yv, levels = c(0L, 1L))
  fit <- suppressMessages(mboost::glmboost(
    .idio_formula_all(vars), data = frame,
    family = if (task == "regression") mboost::Gaussian() else
      mboost::Binomial(),
    control = mboost::boost_control(mstop = max(1L, as.integer(control$rounds))),
    center = FALSE))
  # coef() reports only the terms boosting selected, so the vector would be a
  # different length for each person. Unselected terms are zero, not absent.
  chosen <- tryCatch(suppressMessages(unlist(stats::coef(fit))),
                     error = function(e) NULL)
  beta <- stats::setNames(numeric(length(x)), x)
  if (!is.null(chosen)) {
    named <- intersect(names(chosen), vars)
    beta[match(named, vars)] <- chosen[named]
  }
  list(type = "mboost", fit = fit, vars = vars, coef = beta)
}

# -------------------------------------------------------------- predict ----

#' Predict from a fitted model
#'
#' Regression returns the conditional mean; classification always returns
#' P(positive class), never a label, so every metric downstream sees one scale.
#'
#' @noRd
.idio_ml_predict <- function(fit, newx) {
  if (fit$type == "constant") return(rep(fit$value, nrow(newx)))
  X <- as.matrix(newx)
  Xs <- .idio_apply_scale(X, fit$scale)
  out <- .idio_ml_predict_raw(fit, Xs)

  # Several backends will happily hand back a class LABEL (rpart, ctree,
  # randomForest, qda) or a LINK value (gam, nnet) where this contract is
  # P(positive class). Every one of those failures is silent: the numbers stay
  # finite, thresholding at 0.5 still "works", and only the Brier score looks
  # odd. One guard catches all of them at the boundary instead.
  if (fit$task == "classification" &&
      (!is.numeric(out) || any(out < 0 | out > 1, na.rm = TRUE))) {
    stop("Model \"", fit$type, "\" returned something other than a ",
         "probability. This is a bug in its predict branch.", call. = FALSE)
  }
  out
}

#' @noRd
.idio_ml_predict_raw <- function(fit, Xs) {
  switch(fit$type,
    linear = as.numeric(cbind(1, Xs) %*% fit$beta),
    logit = stats::plogis(as.numeric(cbind(1, Xs) %*% fit$beta)),
    knn = .idio_knn_predict(Xs, fit$x_train, fit$y_train, fit$k),
    tree = {
      j <- match(fit$variable, colnames(Xs))
      out <- ifelse(Xs[, j] <= fit$threshold, fit$left, fit$right)
      if (fit$task == "classification") pmin(pmax(out, 0), 1) else out
    },
    boost = .idio_boost_predict(fit, Xs),
    spline = {
      basis <- .idio_spline_basis(fit, Xs)
      linear <- as.numeric(cbind(1, basis) %*% fit$beta)
      if (fit$task == "classification") stats::plogis(linear) else linear
    },
    naive_bayes = .idio_nb_predict(Xs, fit),
    glmnet = as.numeric(stats::predict(fit$fit, Xs, type = "response")),
    ranger = .idio_ranger_predict(Xs, fit),
    e1071_svm = .idio_svm_predict(Xs, fit),
    e1071_bayes = .idio_e1071_nb_predict(Xs, fit),
    stats_loess = .idio_predict_frame(fit, Xs),
    stats_ppr = .idio_predict_frame(fit, Xs),
    stats_isotonic = stats::approx(fit$knots, fit$values, xout = Xs[, fit$column],
                                   rule = 2L)$y,
    rpart = .idio_rpart_predict(fit, Xs),
    nnet_mlp = as.numeric(stats::predict(
      fit$fit, .idio_named_frame(fit, Xs),
      type = if (fit$task == "regression") "raw" else "raw")),
    nnet_multinom = .idio_multinom_predict(fit, Xs),
    mgcv_gam = as.numeric(stats::predict(fit$fit, .idio_named_frame(fit, Xs),
                                         type = "response")),
    mass_qda = .idio_qda_predict(fit, Xs),
    mass_polr = .idio_polr_predict(fit, Xs),
    xgboost = as.numeric(stats::predict(fit$fit, Xs)),
    kernlab_svm = .idio_kernlab_predict(fit, Xs),
    kernlab_gp = .idio_kernlab_predict(fit, Xs),
    pls = .idio_pls_predict(fit, Xs),
    partykit = .idio_partykit_predict(fit, Xs),
    quantreg = as.numeric(stats::predict(fit$fit, .idio_named_frame(fit, Xs))),
    randomForest = .idio_rf_predict(fit, Xs),
    mboost = .idio_mboost_predict(fit, Xs),
    stop("Unknown fitted model type: ", fit$type, call. = FALSE)
  )
}

#' Newdata with exactly the column names the backend was fitted with
#' @noRd
.idio_named_frame <- function(fit, Xs) {
  frame <- as.data.frame(Xs)
  names(frame) <- fit$vars
  frame
}

.idio_predict_frame <- function(fit, Xs) {
  as.numeric(stats::predict(fit$fit, .idio_named_frame(fit, Xs)))
}

.idio_boost_predict <- function(fit, Xs) {
  steps <- vapply(fit$stumps, .idio_stump_predict, numeric(nrow(Xs)), Xs = Xs)
  total <- fit$intercept + fit$rate * rowSums(as.matrix(steps))
  if (fit$task == "classification") stats::plogis(total) else total
}

.idio_rpart_predict <- function(fit, Xs) {
  frame <- .idio_named_frame(fit, Xs)
  if (fit$task == "regression") {
    return(as.numeric(stats::predict(fit$fit, frame)))
  }
  as.numeric(stats::predict(fit$fit, frame, type = "prob")[, 2L])
}

.idio_multinom_predict <- function(fit, Xs) {
  probs <- stats::predict(fit$fit, .idio_named_frame(fit, Xs), type = "probs")
  if (is.null(dim(probs))) return(as.numeric(probs))
  as.numeric(probs[, ncol(probs)])
}

.idio_qda_predict <- function(fit, Xs) {
  as.numeric(stats::predict(fit$fit, .idio_named_frame(fit, Xs))$posterior[, 2L])
}

.idio_polr_predict <- function(fit, Xs) {
  probs <- stats::predict(fit$fit, .idio_named_frame(fit, Xs), type = "probs")
  if (is.null(dim(probs))) return(as.numeric(probs))
  as.numeric(probs[, ncol(probs)])
}

.idio_kernlab_predict <- function(fit, Xs) {
  if (fit$task == "regression") {
    return(as.numeric(kernlab::predict(fit$fit, Xs)))
  }
  probs <- tryCatch(kernlab::predict(fit$fit, Xs, type = "probabilities"),
                    error = function(e) NULL)
  if (is.null(probs)) {
    return(as.numeric(as.character(kernlab::predict(fit$fit, Xs))))
  }
  as.numeric(probs[, ncol(probs)])
}

.idio_pls_predict <- function(fit, Xs) {
  as.numeric(stats::predict(fit$fit, newdata = list(X = Xs),
                            ncomp = fit$ncomp))
}

.idio_partykit_predict <- function(fit, Xs) {
  frame <- .idio_named_frame(fit, Xs)
  if (fit$task == "regression") {
    return(as.numeric(stats::predict(fit$fit, newdata = frame)))
  }
  probs <- stats::predict(fit$fit, newdata = frame, type = "prob")
  as.numeric(probs[, ncol(probs)])
}

.idio_rf_predict <- function(fit, Xs) {
  if (fit$task == "regression") {
    return(as.numeric(stats::predict(fit$fit, Xs)))
  }
  as.numeric(stats::predict(fit$fit, Xs, type = "prob")[, 2L])
}

.idio_mboost_predict <- function(fit, Xs) {
  frame <- .idio_named_frame(fit, Xs)
  out <- stats::predict(fit$fit, newdata = frame,
                        type = if (fit$task == "regression") "response" else
                          "response")
  as.numeric(out)
}
