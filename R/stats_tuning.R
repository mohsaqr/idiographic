#' Tuning results
#'
#' @param x An idiographic fit.
#' @param model,scope,subject Optional filters.
#' @param n Optional number of rows.
#' @param ... Ignored.
#' @return A tidy tuning table.
#' @export
tuning <- function(x, model = NULL, scope = NULL, subject = NULL, n = NULL,
                   ...) {
  UseMethod("tuning")
}

#' @export
tuning.idiostats_fit <- function(x, model = NULL, scope = NULL,
                                 subject = NULL, n = NULL, ...) {
  tab <- x$tuning %||% .idio_empty_tuning()
  if (!is.null(model)) tab <- tab[tab$model %in% model, , drop = FALSE]
  if (!is.null(scope)) tab <- tab[tab$scope %in% scope, , drop = FALSE]
  if (!is.null(subject)) tab <- tab[tab$subject %in% subject, , drop = FALSE]
  if (!is.null(n)) {
    .idio_count(n, "n")
    tab <- utils::head(tab, n)
  }
  rownames(tab) <- NULL
  tab
}

.idio_empty_tuning <- function() {
  data.frame(scope = character(), model = character(), estimator = character(),
             subject = character(), subgroup = character(),
             parameter = character(), value = character(),
             n = integer(), rmse = numeric(), mae = numeric(),
             accuracy = numeric(), brier = numeric(), rank = integer(),
             stringsAsFactors = FALSE)
}

#' Plot tuning results
#'
#' @param x An idiographic fit.
#' @param model,scope,subject Optional filters.
#' @param metric Metric to plot. Defaults to `rmse` when present, otherwise
#'   `accuracy`.
#' @param ... Passed to base plotting functions.
#' @return Invisibly, the tuning table.
#' @export
plot_tuning <- function(x, model = NULL, scope = NULL, subject = NULL,
                        metric = NULL, ...) {
  tab <- tuning(x, model = model, scope = scope, subject = subject)
  if (!nrow(tab)) {
    plot.new()
    title("No tuning results available")
    return(invisible(tab))
  }
  metric <- metric %||% if ("rmse" %in% names(tab) && any(is.finite(tab$rmse))) {
    "rmse"
  } else {
    "accuracy"
  }
  if (!metric %in% names(tab)) {
    stop("`metric` must be one column in tuning(x).", call. = FALSE)
  }
  labs <- paste(tab$model, tab$parameter, tab$value, sep = ":")
  op <- par(mar = c(8, 4, 3, 1))
  on.exit(par(op), add = TRUE)
  plot(seq_len(nrow(tab)), tab[[metric]], xaxt = "n", xlab = "",
       ylab = metric, main = "Tuning results", pch = 19, ...)
  axis(1, at = seq_len(nrow(tab)), labels = labs, las = 2, cex.axis = 0.8)
  invisible(tab)
}
