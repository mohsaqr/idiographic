.idio_regression_metrics <- function(pred) {
  by <- unique(pred[c("scope", "model", "estimator", "subject", "subgroup")])
  rows <- lapply(seq_len(nrow(by)), function(i) {
    key <- by[i, , drop = FALSE]
    p <- pred[pred$scope == key$scope &
                pred$model == key$model &
                pred$estimator == key$estimator &
                pred$subject == key$subject &
                pred$subgroup == key$subgroup, , drop = FALSE]
    denom <- sum((p$observed - mean(p$observed))^2)
    data.frame(
      key,
      n = nrow(p),
      rmse = sqrt(mean(p$residual^2)),
      mae = mean(abs(p$residual)),
      bias = mean(p$residual),
      r_squared = if (denom > 0) 1 - sum(p$residual^2) / denom else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  overall_keys <- unique(pred[c("scope", "model", "estimator")])
  overall <- lapply(seq_len(nrow(overall_keys)), function(i) {
    key <- overall_keys[i, , drop = FALSE]
    p <- pred[pred$scope == key$scope &
                pred$model == key$model &
                pred$estimator == key$estimator, , drop = FALSE]
    denom <- sum((p$observed - mean(p$observed))^2)
    data.frame(
      key,
      subject = ".overall",
      subgroup = ".all",
      n = nrow(p),
      rmse = sqrt(mean(p$residual^2)),
      mae = mean(abs(p$residual)),
      bias = mean(p$residual),
      r_squared = if (denom > 0) 1 - sum(p$residual^2) / denom else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  out <- rbind(do.call(rbind, rows), do.call(rbind, overall))
  rownames(out) <- NULL
  out
}

.idio_classification_metrics <- function(pred, positive) {
  by <- unique(pred[c("scope", "model", "estimator", "subject", "subgroup")])
  rows <- lapply(seq_len(nrow(by)), function(i) {
    key <- by[i, , drop = FALSE]
    p <- pred[pred$scope == key$scope &
                pred$model == key$model &
                pred$estimator == key$estimator &
                pred$subject == key$subject &
                pred$subgroup == key$subgroup, , drop = FALSE]
    .idio_one_class_metric(p, key, positive)
  })
  overall_keys <- unique(pred[c("scope", "model", "estimator")])
  overall <- lapply(seq_len(nrow(overall_keys)), function(i) {
    key <- overall_keys[i, , drop = FALSE]
    p <- pred[pred$scope == key$scope &
                pred$model == key$model &
                pred$estimator == key$estimator, , drop = FALSE]
    key$subject <- ".overall"
    key$subgroup <- ".all"
    .idio_one_class_metric(p, key, positive)
  })
  out <- rbind(do.call(rbind, rows), do.call(rbind, overall))
  rownames(out) <- NULL
  out
}

.idio_one_class_metric <- function(p, key, positive) {
  eps <- sqrt(.Machine$double.eps)
  prob <- pmin(pmax(p$probability, eps), 1 - eps)
  y <- as.integer(p$observed == positive)
  data.frame(
    key,
    n = nrow(p),
    accuracy = mean(p$observed == p$predicted),
    brier = mean((y - p$probability)^2),
    log_loss = -mean(ifelse(y == 1L, log(prob), log(1 - prob))),
    stringsAsFactors = FALSE
  )
}
