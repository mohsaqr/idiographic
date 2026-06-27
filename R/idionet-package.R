#' idionet: Idiographic Network Estimation from Intensive Longitudinal Data
#'
#' Person-specific and within-person network estimation from intensive
#' longitudinal / ESM panel data: graphical vector autoregression
#' ([graphical_var()]), multilevel vector autoregression ([build_mlvar()]),
#' and Group Iterative Multiple Model Estimation ([build_gimme()]). Each is a
#' clean-room implementation that returns `cograph_network` objects rendered by
#' `cograph::splot()`.
#'
#' @keywords internal
#' @importFrom data.table := CJ as.data.table setkeyv setnames
#' @importFrom stats cov2cor sd
#' @importFrom utils globalVariables
"_PACKAGE"

# data.table uses non-standard evaluation (`.N`, `.`, and the `.first`/`.last`
# column names created in .mlvar_augment_data); register them so R CMD check
# does not flag them as undefined global variables. utils::globalVariables also
# gives the otherwise-unused `utils` import a concrete use.
utils::globalVariables(c(".", ".N", ".first", ".last"))
