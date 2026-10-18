#' Units that could not be fitted
#'
#' Returns the failure table of a result: one row per unit (person, window,
#' model or resample) whose estimation failed or was skipped, with the reason.
#' Persons with too few complete training or held-out occasions, for example,
#' receive no person-specific model and are listed here instead of being
#' dropped silently.
#'
#' @param x A result that records failures, such as a fit from [fit_lm()],
#'   [fit_glm()], [fit_within_between()], [fit_ml()] or [fit_effects()], a
#'   subgroup result from [find_subgroups()], a rolling network result, or a
#'   model comparison.
#' @param model,scope,subject Optional filters, applied when the table has the
#'   matching column.
#' @param ... Ignored.
#' @return A base `data.frame` with one row per failed unit. For model fits the
#'   columns are `scope`, `model`, `estimator`, `subject` and `message`; other
#'   results keep the identifying columns of their own units and a `message`
#'   column. A result without failures returns a table with zero rows.
#' @section Errors:
#' Raises an error of class `idiographic_no_failure_table` when `x` keeps no
#' failure table.
#' @examples
#' # Aisha keeps only 8 days, too few for a person-specific model.
#' short <- subset(srl, name != "Aisha" | day <= 8)
#' fit <- fit_lm(short, y = "effort", x = "efficacy", id = "name",
#'               time = "day", scope = "individual")
#' failures(fit)
#' @export
failures <- function(x, model = NULL, scope = NULL, subject = NULL, ...) {
  UseMethod("failures")
}

#' @rdname failures
#' @export
failures.default <- function(x, model = NULL, scope = NULL, subject = NULL,
                             ...) {
  tab <- if (is.list(x)) x[["failures"]] else NULL
  if (is.null(tab)) {
    stop(errorCondition(
      sprintf("An object of class `%s` keeps no failure table.",
              class(x)[[1L]]),
      class = "idiographic_no_failure_table", call = NULL))
  }
  stopifnot("The failure table must be a data frame" = is.data.frame(tab))
  .idio_filter_table(as.data.frame(tab), model = model, scope = scope,
                     subject = subject)
}
