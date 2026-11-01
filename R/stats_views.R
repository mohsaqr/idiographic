#' Focus an idiographic fit on one person
#'
#' @param x An idiographic fit.
#' @param id Person ID.
#' @param ... Ignored.
#' @return An `idiographic_fit` of the same structure as `x` whose metric,
#'   prediction, coefficient and tuning tables are restricted to the person-specific models of `id`, so
#'   that [metrics()], [predictions()] and [coefs()] report only those rows.
#' @examples
#' fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
#' person(fit, "Aisha") |> coefs()
#' @export
person <- function(x, id, ...) UseMethod("person")

#' @export
person.idiostats_fit <- function(x, id, ...) {
  people(x, id)
}

#' Focus an idiographic fit on selected people
#'
#' @param x An idiographic fit.
#' @param ids Person IDs.
#' @return An `idiographic_fit` of the same structure as `x` whose metric,
#'   prediction, coefficient and tuning tables are restricted to the person-specific models of `ids`, so
#'   that [metrics()], [predictions()] and [coefs()] report only those rows.
#' @examples
#' fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
#' people(fit, c("Aisha", "Alice")) |> metrics()
#' @export
people <- function(x, ids) {
  .idio_view(x, subject = ids, scope = "individual")
}

#' Focus an idiographic fit on all individual models
#'
#' @param x An idiographic fit.
#' @return An `idiographic_fit` of the same structure as `x` whose metric,
#'   prediction, coefficient and tuning tables are restricted to the person-specific (`"individual"`) scope, so
#'   that [metrics()], [predictions()] and [coefs()] report only those rows.
#' @examples
#' fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
#' individuals(fit) |> coefs(term = "efficacy", n = 5)
#' @export
individuals <- function(x) {
  .idio_view(x, scope = "individual")
}

#' Focus an idiographic fit on pooled models
#'
#' @param x An idiographic fit.
#' @return An `idiographic_fit` of the same structure as `x` whose metric,
#'   prediction, coefficient and tuning tables are restricted to the pooled scope, so
#'   that [metrics()], [predictions()] and [coefs()] report only those rows.
#' @examples
#' fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
#' pooled(fit) |> coefs()
#' @export
pooled <- function(x) {
  .idio_view(x, scope = "pooled")
}

#' Focus an idiographic fit on subgroup models
#'
#' @param x An idiographic fit.
#' @param label Optional subgroup label(s). Defaults to every subgroup.
#' @return An `idiographic_fit` of the same structure as `x` whose metric,
#'   prediction, coefficient and tuning tables are restricted to the subgroup scope (and to `label` when given), so
#'   that [metrics()], [predictions()] and [coefs()] report only those rows.
#' @examples
#' g <- find_subgroups(srl, y = "effort", x = "efficacy:monitoring",
#'                     id = "name", k = 2, reps = 10)
#' fit <- fit_subgroups(srl, y = "effort", x = "efficacy:monitoring",
#'                      id = "name", subgroup = g, time = "day")
#' fit |> subgroups() |> metrics(overall = TRUE)
#' @export
subgroups <- function(x, label = NULL) {
  .idio_view(x, scope = "subgroup", subgroup = label)
}

#' Focus an idiographic fit on overall metric rows
#'
#' @param x An idiographic fit.
#' @return An `idiographic_fit` of the same structure as `x` whose metric and
#'   tuning tables keep only the `.overall` rows; predictions and coefficients
#'   are unchanged.
#' @examples
#' fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
#' overall(fit) |> metrics()
#' @export
overall <- function(x) {
  .idio_view(x, overall = TRUE)
}

.idio_view <- function(x, scope = NULL, subject = NULL, subgroup = NULL,
                       overall = FALSE) {
  if (!inherits(x, "idiostats_fit")) {
    stop("Expected a consolidated idiographic fit.", call. = FALSE)
  }
  out <- x
  out$metrics <- .idio_filter_table(out$metrics, scope = scope,
                                    subject = subject, subgroup = subgroup,
                                    overall = overall)
  out$predictions <- .idio_filter_table(out$predictions, scope = scope,
                                        subject = subject, subgroup = subgroup)
  out$coefs <- .idio_filter_table(out$coefs, scope = scope, subject = subject,
                                  subgroup = subgroup)
  out$tuning <- .idio_filter_table(out$tuning %||% .idio_empty_tuning(),
                                   scope = scope, subject = subject,
                                   subgroup = subgroup, overall = overall)
  out
}
