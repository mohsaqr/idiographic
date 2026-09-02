#' idiographic: Person-Specific Statistics and Dynamic Networks
#'
#' Person-specific and within-person analysis of intensive longitudinal and ESM
#' panel data. The statistical workflow includes person-level descriptions
#' ([describe_persons()]), centring, decomposition, and lagging
#' ([preprocess_panel()]), scoped regression ([fit_lm()], [fit_glm()]), machine
#' learning ([fit_ml()]), within-between effects ([fit_within_between()]),
#' coefficient pooling ([pool_coefs()]), subgroup analysis
#' ([test_subgroups()], [find_subgroups()]), treatment effects
#' ([fit_effects()]), and heterogeneity ([fit_heterogeneity()]).
#'
#' Dynamic-network methods include network preprocessing audits
#' ([preprocess()]), edge-stability diagnostics ([estimate_stability()]),
#' rolling forecast validation ([validate_forecast()]), ordinary and graphical
#' vector autoregression ([fit_var()], [fit_graphical_var()]), multilevel and
#' Bayesian VAR ([fit_mlvar()], [fit_mlvar_bayes()]), unified SEM
#' ([fit_usem()]), and GIMME ([fit_gimme()]). Use [fit_idiographic()] for
#' registry-driven dispatch or the direct `fit_*()` functions. Results provide
#' tidy accessors, readable print methods, diagnostics, and plots appropriate
#' to their analytical level. [equivalence()] reports the exact validation
#' scope attached to registered network methods.
#'
#' @importFrom grDevices rgb
#' @importFrom graphics abline arrows axis barplot legend lines par plot.new
#'   points title
#' @importFrom stats ave cov2cor effects median qlogis sd setNames
#' @importFrom utils tail
"_PACKAGE"
