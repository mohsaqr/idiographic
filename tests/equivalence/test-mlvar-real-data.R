# fit_mlvar() on 20 real experience-sampling panels against mlVAR::mlVAR() 0.7.3, run here on the same files.
#
# THE DATA ARE NOT REDISTRIBUTABLE. data/mlvar-real20/ holds participant-level experience-sampling panels from
# twenty studies (copied from Dynalytics_Desktop/validation/data; see validation/fixtures/mlvar-real20/ for their
# selection and the edge cases they carry). They are attached to this case for the owner's private re-run only.
#
# The configuration is the one mlVAR and idiographic both validate: lag 1, lme4, fixed temporal and fixed
# contemporaneous effects, unstandardised. As in test-mlvar.R, both sides fit the mixed models with lme4, so this
# checks idiographic's preparation and extraction against mlVAR's on real panels with gaps, sparse persons, a
# missing identifier (0008) and singular between-person covariances (0003, 0022).

restricted <- "Participant-level experience-sampling data: not redistributable."

panels <- jsonlite::fromJSON(reference_data("data/mlvar-real20/config.json"), simplifyVector = FALSE)$datasets

test_that("20 real panels: temporal, contemporaneous and between-person networks", {
  skip_without_reference("mlVAR")
  tables <- lapply(panels, \(panel) {
    vars <- unlist(panel$vars)
    data <- utils::read.csv(reference_data(sprintf("data/mlvar-real20/%s-data.csv", panel$id)), stringsAsFactors = FALSE)
    ours <- fit_mlvar(data, vars = vars, id = "id", day = "day", beep = "beep", lags = 1, estimator = "lmer",
                      temporal = "fixed", contemporaneous = "fixed", scale = FALSE)
    # mlVAR warns about singular between-person fits on 0003 and 0022; its output is the reference as it is.
    reference <- suppressWarnings(mlVAR::mlVAR(data, vars = vars, idvar = "id", dayvar = "day", beepvar = "beep",
                                               lags = 1, estimator = "lmer", temporal = "fixed",
                                               contemporaneous = "fixed", scale = FALSE, verbose = FALSE))
    # API gap: matrices() returns a list of matrices, so each layer is reached by name; every cell is compared,
    # zeros included.
    layers <- matrices(ours)
    list(ours = cbind(panel = panel$id, ref_network(temporal = layers[["temporal"]],
                                                     contemporaneous = layers[["contemporaneous"]],
                                                     between = layers[["between"]])),
         theirs = cbind(panel = panel$id, mlvar_networks(reference)))
  })
  ours <- do.call(rbind, lapply(tables, \(t) t$ours))
  theirs <- do.call(rbind, lapply(tables, \(t) t$theirs))
  estimable <- !is.na(theirs$weight)
  # 1e-6, not 1e-8: lme4's fits of these large panels (up to 21,570 rows) differ in the seventh digit between the
  # BLAS/LAPACK of macOS and Ubuntu (largest seen 2.7e-7, validation/fixtures/mlvar-real20/RESULTS.md).
  expect_reference(ours[estimable, ], theirs[estimable, ], reference = "mlVAR",
                   covers = c("fit_mlvar()", "matrices()", "matrices.net_mlvar()"),
                   quantity = "real panels, three networks", tolerance = 1e-6, key = c("panel", "network", "from", "to"),
                   note = restricted)
  singular <- ours$panel %in% theirs$panel[!estimable] & ours$network == "between"
  expect_not_comparable(ours[singular, ], theirs[singular, ], reference = "mlVAR", covers = "fit_mlvar()",
                        quantity = "real panels with a singular between-person covariance", key = c("panel", "network", "from", "to"),
                        reason = "A random-intercept standard deviation is estimated at zero, so the between-person partial correlations are not defined: mlVAR returns NA, idiographic its documented zero network.")
})
