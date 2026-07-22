#' idiographic: Idiographic Network Estimation from Intensive Longitudinal Data
#'
#' Person-specific and within-person network estimation from intensive
#' longitudinal / ESM panel data: preprocessing audits
#' ([preprocess()]), edge-stability diagnostics
#' ([estimate_stability()]), model-comparison reports
#' ([compare_idiographic()]), rolling forecast validation
#' ([validate_forecast()]), rolling ordinary vector autoregression
#' ([fit_rolling_var()]), rolling graphical vector autoregression
#' ([fit_rolling_graphical_var()]), ordinary vector autoregression ([fit_var()]),
#' graphical vector autoregression ([fit_graphical_var()]), multilevel vector
#' autoregression ([fit_mlvar()]), unified SEM ([fit_usem()]), Group
#' Iterative Multiple Model Estimation ([fit_gimme()]), and idiographic
#' supervised machine-learning models ([fit_ml()]) for
#' individualized prediction. Use [fit_idiographic()] for registry-driven
#' dispatch or the direct `fit_*()` functions. Every result has tidy
#' `as.data.frame()`, [summary()], and print methods; network estimators also
#' share [edges()], [coefs()], [nodes()], [matrices()], and plotting methods.
#' [equivalence()] reports the exact validation scope attached to each method.
#'
#' @importFrom stats cov2cor median qlogis sd setNames
#' @importFrom utils tail
"_PACKAGE"
