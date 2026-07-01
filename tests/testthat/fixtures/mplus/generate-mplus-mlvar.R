# Generate Mplus DSEM ground-truth fixtures for build_mlvar_bayes() parity tests.
#
# Requires Mplus (here the version 9 DEMO) + mlVAR + MplusAutomation. Because the
# DEMO caps models at 2 independent / 2 between variables, all fixtures are d = 2.
# Mplus truncates input lines at 90 chars, so runs happen in a SHORT directory.
#
# Run manually to (re)build fixtures:
#   Rscript tests/testthat/fixtures/mplus/generate-mplus-mlvar.R
# Fixtures are written next to this script as mlvar_<tag>.rds and are the frozen
# ground truth the tests compare against (no Mplus needed at test time).

suppressWarnings(suppressMessages({
  library(mlVAR); library(MplusAutomation)
}))

`%||%` <- function(a, b) if (is.null(a)) b else a
# Resolve this script's directory (works under Rscript and source()).
.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", .args[grep("^--file=", .args)])
FIX_DIR <- if (length(.file) == 1L && nzchar(.file)) {
  dirname(normalizePath(.file))
} else {
  "/Users/mohammedsaqr/Documents/Github/idiographic/tests/testthat/fixtures/mplus"
}

simulate_var2 <- function(n_id, n_t, Phi, Theta, mu_sd = 0.5, seed = 1) {
  set.seed(seed); d <- 2L; L <- t(chol(Theta))
  one <- function(id) {
    y <- matrix(0, n_t, d); mu_i <- rnorm(d, 0, mu_sd)
    for (t in 2:n_t)
      y[t, ] <- mu_i + Phi %*% (y[t - 1, ] - mu_i) + as.numeric(L %*% rnorm(d))
    data.frame(id = id, beep = seq_len(n_t), V1 = y[, 1], V2 = y[, 2])
  }
  do.call(rbind, lapply(seq_len(n_id), one))
}

# Extract B, Sigma_W, Sigma_B, alpha (est/SD/CI) from a parsed Mplus mlVAR .out.
extract_truth <- function(out_path, vars = c("V1", "V2")) {
  m <- readModels(out_path, quiet = TRUE)
  pu <- m$parameters$unstandardized
  p <- length(vars); mat0 <- function() matrix(0, p, p, dimnames = list(vars, vars))
  B <- Bsd <- Blo <- Bhi <- mat0(); SW <- SB <- mat0()
  alpha <- stats::setNames(numeric(p), vars)
  vi <- function(v) match(v, vars)
  for (r in seq_len(nrow(pu))) {
    hdr <- pu$paramHeader[r]; par <- pu$param[r]; est <- pu$est[r]
    lvl <- pu$BetweenWithin[r]
    if (grepl("\\.ON$", hdr)) {                         # within temporal B
      out <- vi(sub("\\.ON$", "", hdr)); pr <- vi(sub("&1$", "", par))
      B[out, pr] <- est; Bsd[out, pr] <- pu$posterior_sd[r]
      Blo[out, pr] <- pu$lower_2.5ci[r]; Bhi[out, pr] <- pu$upper_2.5ci[r]
    } else if (hdr == "Residual.Variances") {
      SW[vi(par), vi(par)] <- est
    } else if (hdr == "Variances" && lvl == "Between") {
      SB[vi(par), vi(par)] <- est
    } else if (grepl("\\.WITH$", hdr)) {
      a <- vi(sub("\\.WITH$", "", hdr)); b <- vi(par)
      if (lvl == "Within") { SW[a, b] <- SW[b, a] <- est }
      else { SB[a, b] <- SB[b, a] <- est }
    } else if (hdr == "Means" && lvl == "Between") {
      alpha[vi(par)] <- est
    }
  }
  list(B = B, B_sd = Bsd, B_lo = Blo, B_hi = Bhi,
       Sigma_W = SW, Sigma_B = SB, alpha = alpha)
}

run_fixture <- function(tag, n_id, n_t, Phi, Theta, seed) {
  dat <- simulate_var2(n_id, n_t, Phi, Theta, seed = seed)
  wd <- file.path("/tmp/mp", paste0("fx_", tag))
  dir.create(wd, recursive = TRUE, showWarnings = FALSE)
  old <- setwd(wd); on.exit(setwd(old))
  fit <- mlVAR(dat, vars = c("V1", "V2"), idvar = "id", beepvar = "beep",
               lags = 1, estimator = "Mplus", temporal = "fixed",
               contemporaneous = "fixed", MplusSave = TRUE, MplusName = tag,
               iterations = "(10000)", chains = 2, verbose = FALSE)
  truth <- extract_truth(file.path(wd, paste0(tag, ".out")))
  setwd(old)
  fixture <- list(
    tag = tag, data = dat, vars = c("V1", "V2"), id = "id", beep = "beep",
    sim = list(Phi = Phi, Theta = Theta, n_id = n_id, n_t = n_t, seed = seed),
    mplus = truth,
    meta = list(estimator = "Mplus DSEM (v9 DEMO)", temporal = "fixed",
                contemporaneous = "fixed", iterations = "(10000)", chains = 2))
  saveRDS(fixture, file.path(FIX_DIR, paste0("mlvar_", tag, ".rds")))
  cat(sprintf("[%s] B=[[%.3f,%.3f],[%.3f,%.3f]] SW11=%.3f SB11=%.3f -> saved\n",
              tag, truth$B[1,1], truth$B[1,2], truth$B[2,1], truth$B[2,2],
              truth$Sigma_W[1,1], truth$Sigma_B[1,1]))
  invisible(fixture)
}

Ph <- function(a11, a12, a21, a22) matrix(c(a11, a12, a21, a22), 2, 2, byrow = TRUE)
Th <- function(rho) matrix(c(1, rho, rho, 1), 2, 2)

run_fixture("base",   n_id = 12, n_t = 50, Ph(.30, .15, .10, .30), Th(.30), seed = 123)
run_fixture("diag",   n_id = 20, n_t = 40, Ph(.35, .00, .00, .25), Th(.20), seed = 7)
run_fixture("strong", n_id = 15, n_t = 60, Ph(.40, .20, .25, .35), Th(.40), seed = 42)
run_fixture("neg",    n_id = 18, n_t = 45, Ph(.30,-.15,-.10, .30), Th(-.25), seed = 99)
run_fixture("short",  n_id = 25, n_t = 25, Ph(.25, .10, .05, .30), Th(.15), seed = 5)
cat("ALL FIXTURES DONE\n")
