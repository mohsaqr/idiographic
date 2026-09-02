#' Focus an idiostats fit on one person
#'
#' @param x An idiostats fit.
#' @param id Person ID.
#' @param ... Ignored.
#' @return An idiostats fit view.
#' @export
person <- function(x, id, ...) UseMethod("person")

#' @export
person.idiostats_fit <- function(x, id, ...) {
  people(x, id)
}

#' Focus an idiostats fit on selected people
#'
#' @param x An idiostats fit.
#' @param ids Person IDs.
#' @return An idiostats fit view.
#' @export
people <- function(x, ids) {
  .idio_view(x, subject = ids, scope = "individual")
}

#' Focus an idiostats fit on all individual models
#'
#' @param x An idiostats fit.
#' @return An idiostats fit view.
#' @export
individuals <- function(x) {
  .idio_view(x, scope = "individual")
}

#' Focus an idiostats fit on pooled models
#'
#' @param x An idiostats fit.
#' @return An idiostats fit view.
#' @export
pooled <- function(x) {
  .idio_view(x, scope = "pooled")
}

#' Focus an idiostats fit on subgroup models
#'
#' @param x An idiostats fit.
#' @param label Optional subgroup label(s). Defaults to every subgroup.
#' @return An idiostats fit view.
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

#' Focus an idiostats fit on overall metric rows
#'
#' @param x An idiostats fit.
#' @return An idiostats fit view.
#' @export
overall <- function(x) {
  .idio_view(x, overall = TRUE)
}

.idio_view <- function(x, scope = NULL, subject = NULL, subgroup = NULL,
                       overall = FALSE) {
  if (!inherits(x, "idiostats_fit")) {
    stop("Expected an idiostats fit.", call. = FALSE)
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
