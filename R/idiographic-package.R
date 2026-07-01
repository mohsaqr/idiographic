#' idiographic: Idiographic Network Estimation from Intensive Longitudinal Data
#'
#' Person-specific and within-person network estimation from intensive
#' longitudinal / ESM panel data: preprocessing audits
#' ([audit_preprocess()]), edge-stability diagnostics
#' ([estimate_stability()]), model-comparison reports
#' ([compare_idiographic()]), rolling forecast validation
#' ([validate_forecast()]), rolling ordinary vector autoregression
#' ([rolling_var()]), rolling graphical vector autoregression
#' ([rolling_graphical_var()]), ordinary vector autoregression ([build_var()]),
#' graphical vector autoregression ([graphical_var()]), multilevel vector
#' autoregression ([build_mlvar()]), unified SEM ([build_usem()]), and Group
#' Iterative Multiple Model Estimation ([build_gimme()]). Each estimator is
#' implemented clean-room and returns tidy access through [edges()], [coefs()],
#' [nodes()], and [summary()].
#'
#' @keywords internal
#' @importFrom stats cov2cor sd
"_PACKAGE"
