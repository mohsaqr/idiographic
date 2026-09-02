#' Feature importance
#'
#' Returns a tidy feature-importance table. For coefficient-based native models,
#' importance is the absolute coefficient magnitude after the model's internal
#' scaling. For simple tree models, the selected split variable receives the
#' split contrast magnitude.
#'
#' @param x An idiostats fit.
#' @param model,scope,subject Optional filters.
#' @param method,repeats Only for [importance()]. `"coefficient"` (the default) uses the size of each
#'   standardized coefficient, which only describes models that have
#'   coefficients. `"permutation"` shuffles each predictor in the held-out rows
#'   and reports how much worse the model gets -- model-agnostic, so it also
#'   explains `knn`, forests, kernel machines and boosted ensembles, which
#'   otherwise return nothing at all; `repeats` is the number of shuffles.
#' @param n Optional number of rows.
#' @param ... Ignored.
#' @return A tidy data frame.
#' @export
importance <- function(x, model = NULL, scope = NULL, subject = NULL, n = NULL,
                       method = c("coefficient", "permutation"), repeats = 5L,
                       ...) UseMethod("importance")

#' Permutation importance: how much worse does the model get without a variable
#'
#' Model-agnostic by construction. A coefficient-based importance can only
#' describe models that HAVE coefficients, which silently excludes knn,
#' forests, kernel machines and every boosted ensemble -- exactly the models
#' most likely to win. Here each predictor is shuffled in the held-out rows and
#' the increase in error is recorded, so every model is measured on the same
#' scale: how much accuracy that predictor was worth.
#'
#' Shuffling breaks the predictor's relationship with the outcome while leaving
#' its marginal distribution intact, so the comparison is against the same model
#' rather than against a refitted one.
#'
#' @noRd
.idio_permutation_importance <- function(x, model, scope, subject, n,
                                         repeats) {
  .idio_count(repeats, "repeats")
  fits <- x$fits
  if (!length(fits)) return(.idio_empty_importance())
  pred <- predictions(x, model = model, scope = scope, subject = subject)
  if (!nrow(pred)) return(.idio_empty_importance())
  data <- x$data
  if (is.null(data)) {
    stop("Permutation importance needs the rows the model was scored on, and ",
         "this fit did not keep them.", call. = FALSE)
  }
  vars <- x$spec$x
  keys <- unique(pred[c("scope", "model", "estimator", "subject", "subgroup")])

  rows <- lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, , drop = FALSE]
    part <- pred[pred$scope == key$scope & pred$model == key$model &
                   pred$estimator == key$estimator &
                   pred$subject == key$subject &
                   pred$subgroup == key$subgroup, , drop = FALSE]
    label <- if (key$scope == "individual") key$subject else key$subgroup
    fit <- fits[[paste(key$scope, key$model, label, sep = ":")]]
    if (is.null(fit) || !nrow(part)) return(NULL)
    newx <- data[match(part$row, data$.idio_row), vars, drop = FALSE]
    if (anyNA(newx)) return(NULL)
    observed <- .idio_importance_error(part, x$spec$task, x$y_info)

    gain <- vapply(vars, function(v) {
      losses <- vapply(seq_len(repeats), function(r) {
        shuffled <- newx
        shuffled[[v]] <- sample(shuffled[[v]])
        scrambled <- .idio_ml_predict(fit, shuffled)
        .idio_importance_loss(part$observed, scrambled, x$spec$task,
                              x$y_info)
      }, numeric(1))
      mean(losses) - observed
    }, numeric(1))

    data.frame(scope = key$scope, model = key$model,
               estimator = key$estimator, subject = key$subject,
               subgroup = key$subgroup, variable = vars,
               importance = as.numeric(gain), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) return(.idio_empty_importance())
  out <- out[order(-out$importance), , drop = FALSE]
  if (!is.null(n)) {
    .idio_count(n, "n")
    out <- utils::head(out, n)
  }
  rownames(out) <- NULL
  out
}

#' Error of the model as fitted, on the same rows
#' @noRd
.idio_importance_error <- function(part, task, y_info) {
  if (task == "classification") {
    truth <- as.integer(part$observed == y_info$positive)
    return(mean((truth - as.numeric(part$probability))^2))
  }
  sqrt(mean(part$residual^2))
}

#' Error after shuffling one predictor
#' @noRd
.idio_importance_loss <- function(observed, predicted, task, y_info) {
  if (task == "classification") {
    truth <- as.integer(observed == y_info$positive)
    return(mean((truth - predicted)^2))
  }
  sqrt(mean((as.numeric(observed) - predicted)^2))
}

#' @export
importance.idiostats_fit <- function(x, model = NULL, scope = NULL,
                                     subject = NULL, n = NULL,
                                     method = c("coefficient", "permutation"),
                                     repeats = 5L, ...) {
  method <- match.arg(method)
  if (method == "permutation") {
    return(.idio_permutation_importance(x, model, scope, subject, n, repeats))
  }
  tab <- coefs(x, model = model, scope = scope, subject = subject)
  if (!nrow(tab)) return(.idio_empty_importance())
  tab <- tab[!tab$term %in% c("(Intercept)", "mean", "probability", "k"), ,
             drop = FALSE]
  if (!nrow(tab)) return(.idio_empty_importance())
  variable <- tab$term
  tree <- grepl("^threshold:", variable)
  variable[tree] <- sub("^threshold:", "", variable[tree])
  imp <- abs(tab$estimate)
  out <- data.frame(
    scope = tab$scope,
    model = tab$model,
    estimator = tab$estimator,
    subject = tab$subject,
    subgroup = tab$subgroup,
    variable = variable,
    importance = imp,
    stringsAsFactors = FALSE
  )
  agg <- stats::aggregate(
    importance ~ scope + model + estimator + subject + subgroup + variable,
    out, mean
  )
  agg <- agg[order(-agg$importance), , drop = FALSE]
  if (!is.null(n)) {
    .idio_count(n, "n")
    agg <- utils::head(agg, n)
  }
  rownames(agg) <- NULL
  agg
}

.idio_empty_importance <- function() {
  data.frame(scope = character(), model = character(), estimator = character(),
             subject = character(), subgroup = character(),
             variable = character(), importance = numeric(),
             stringsAsFactors = FALSE)
}

#' Model diagnostics
#'
#' @param x An idiostats fit.
#' @param model,scope,subject Optional filters.
#' @param n Optional number of rows.
#' @param ... Ignored.
#' @return A tidy row-level diagnostic table.
#' @export
diagnostics <- function(x, model = NULL, scope = NULL, subject = NULL, n = NULL,
                        ...) UseMethod("diagnostics")

#' @export
diagnostics.idiostats_fit <- function(x, model = NULL, scope = NULL,
                                      subject = NULL, n = NULL, ...) {
  pred <- predictions(x, model = model, scope = scope, subject = subject)
  if (!nrow(pred)) return(pred)
  if ("residual" %in% names(pred)) {
    pred$abs_error <- abs(pred$residual)
    pred$squared_error <- pred$residual^2
    pred$std_residual <- ave(pred$residual,
                             interaction(pred$scope, pred$model, pred$estimator,
                                         pred$subject, drop = TRUE),
                             FUN = function(z) {
                               s <- stats::sd(z, na.rm = TRUE)
                               if (!is.finite(s) || s == 0) return(rep(NA_real_, length(z)))
                               z / s
                             })
  } else if ("probability" %in% names(pred)) {
    pred$correct <- pred$observed == pred$predicted
    positive <- pred$predicted[pred$probability >= 0.5][1L]
    if (is.na(positive)) positive <- pred$predicted[which.max(pred$probability)]
    y <- as.integer(pred$observed == positive)
    pred$brier <- (y - pred$probability)^2
  }
  if (!is.null(n)) {
    .idio_count(n, "n")
    pred <- utils::head(pred, n)
  }
  rownames(pred) <- NULL
  pred
}
