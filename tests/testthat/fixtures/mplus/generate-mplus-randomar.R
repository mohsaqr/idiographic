# Generate an Mplus DSEM univariate random-AR(1) ground-truth fixture for
# validating the random-slope engine of fit_mlvar_bayes(temporal = "random").
# The Mplus DEMO caps time-series latent variables at 2, so a univariate random
# intercept + random slope (2 latent vars) is the only Mplus-checkable random
# case; the multivariate engine is validated by parameter recovery instead.
# Run: Rscript tests/testthat/fixtures/mplus/generate-mplus-randomar.R
suppressWarnings(suppressMessages(library(MplusAutomation)))
.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", .args[grep("^--file=", .args)])
FIX_DIR <- if (length(.file) == 1L && nzchar(.file)) {
  dirname(normalizePath(.file))
} else {
  "/Users/mohammedsaqr/Documents/Github/idiographic/tests/testthat/fixtures/mplus"
}

set.seed(2024); n_id <- 40; n_t <- 50
gamma_true <- c(mu = 0, phi = 0.35)
Sre_true <- matrix(c(0.36, 0.03, 0.03, 0.0225), 2, 2)
L <- t(chol(Sre_true))
rows <- lapply(seq_len(n_id), function(i) {
  re <- gamma_true + as.numeric(L %*% rnorm(2)); mu_i <- re[1]; phi_i <- re[2]
  y <- numeric(n_t); y[1] <- mu_i + rnorm(1)
  for (t in 2:n_t) y[t] <- mu_i + phi_i * (y[t - 1] - mu_i) + rnorm(1)
  data.frame(id = i, beep = seq_len(n_t), V1 = y)
})
dat <- do.call(rbind, rows)
dat$V1 <- as.numeric(scale(dat$V1))

wd <- "/tmp/mp/rar_fx"; dir.create(wd, recursive = TRUE, showWarnings = FALSE)
prepareMplusData(dat[, c("V1", "id")], file.path(wd, "r.dat"))
writeLines(c(
  "TITLE: univariate random AR(1)",
  "DATA: FILE = r.dat;",
  "VARIABLE: NAMES = V1 id; USEVARIABLES = V1; CLUSTER = id; LAGGED = V1(1);",
  "ANALYSIS: TYPE = TWOLEVEL RANDOM; ESTIMATOR = BAYES; BITERATIONS = (10000); CHAINS = 2;",
  "MODEL:", "%WITHIN%", "  s | V1 ON V1&1;",
  "%BETWEEN%", "  V1 s;", "  V1 WITH s;", "OUTPUT: TECH1 TECH8;"),
  file.path(wd, "r.inp"))
old <- setwd(wd); runModels("r.inp", showOutput = FALSE); setwd(old)
pu <- readModels(file.path(wd, "r.out"), quiet = TRUE)$parameters$unstandardized
val <- function(hdr, par) pu$est[pu$paramHeader == hdr & pu$param == par][1]

truth <- list(
  gamma_mu  = val("Means", "V1"),
  gamma_phi = val("Means", "S"),
  sigma2    = val("Residual.Variances", "V1"),
  var_mu    = val("Variances", "V1"),
  var_phi   = val("Variances", "S"),
  cov_muphi = val("V1.WITH", "S"))
fixture <- list(tag = "randomar", data = dat, vars = "V1", id = "id",
                beep = "beep", mplus = truth,
                sim = list(gamma = gamma_true, Sre = Sre_true,
                           n_id = n_id, n_t = n_t),
                meta = list(estimator = "Mplus DSEM random-AR (v9 DEMO)"))
saveRDS(fixture, file.path(FIX_DIR, "randomar.rds"))
cat(sprintf("[randomar] gamma_phi=%.3f var_phi=%.4f sigma2=%.3f var_mu=%.3f saved\n",
            truth$gamma_phi, truth$var_phi, truth$sigma2, truth$var_mu))
