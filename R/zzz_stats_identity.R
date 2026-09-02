# Primary S3 registrations for statistical results after the idiostats merge.
#
# The legacy class remains second in each class vector so downstream code can
# migrate gradually. Registering both names makes the surviving package
# identity explicit to S3 discovery as well as to `class()`.

#' Convert a consolidated fit to its prediction table
#'
#' @param x A consolidated `idiographic_fit`.
#' @param row.names Ignored.
#' @param optional Ignored.
#' @param ... Filters passed to [predictions()].
#' @return A prediction `data.frame`.
#' @export
as.data.frame.idiographic_fit <- function(x, row.names = NULL,
                                          optional = FALSE, ...) {
  predictions(x, ...)
}

#' @rdname as.data.frame.idiographic_fit
#' @export
as.data.frame.idiostats_fit <- as.data.frame.idiographic_fit

#' Summarise a consolidated fit
#'
#' @param object A consolidated `idiographic_fit`.
#' @param ... Filters passed to [metrics()].
#' @return A model-metrics `data.frame`.
#' @export
summary.idiographic_fit <- function(object, ...) metrics(object, ...)

#' @rdname summary.idiographic_fit
#' @export
summary.idiostats_fit <- summary.idiographic_fit

#' @export
as.data.frame.idiographic_subgroup_test <-
  as.data.frame.idiostats_subgroup_test
#' @export
best_model.idiographic_fit <- best_model.idiostats_fit
#' @export
coefs.idiographic_fit <- coefs.idiostats_fit
#' @export
contextual.idiographic_wb <- contextual.idiostats_wb
#' @export
diagnostics.idiographic_fit <- diagnostics.idiostats_fit
#' @export
effects.idiographic_effects <- effects.idiostats_effects
#' @export
groups.idiographic_fit <- groups.idiostats_fit
#' @export
groups.idiographic_groups <- groups.idiostats_groups
#' @export
importance.idiographic_fit <- importance.idiostats_fit
#' @export
metrics.idiographic_fit <- metrics.idiostats_fit
#' @export
person.idiographic_fit <- person.idiostats_fit
#' @export
predictions.idiographic_fit <- predictions.idiostats_fit
#' @export
print.idiographic_contextual <- print.idiostats_contextual
#' @export
print.idiographic_correlations <- print.idiostats_correlations
#' @export
print.idiographic_descriptives <- print.idiostats_descriptives
#' @export
print.idiographic_effects <- print.idiostats_effects
#' @export
print.idiographic_fit <- print.idiostats_fit
#' @export
print.idiographic_groups <- print.idiostats_groups
#' @export
print.idiographic_heterogeneity <- print.idiostats_heterogeneity
#' @export
print.idiographic_models <- print.idiostats_models
#' @export
print.idiographic_pooled <- print.idiostats_pooled
#' @export
print.idiographic_shrunk <- print.idiostats_shrunk
#' @export
print.idiographic_subgroup_test <- print.idiostats_subgroup_test
#' @export
print.idiographic_variance <- print.idiostats_variance
#' @export
print.idiographic_wb <- print.idiostats_wb
#' @export
tuning.idiographic_fit <- tuning.idiostats_fit
#' @export
variance_components.idiographic_wb <- variance_components.idiostats_wb
