# Generate Mplus single-subject Bayesian VAR(1) ground-truth fixtures for
# build_var_bayes() parity tests. Mplus fits the VAR as a Bayesian regression on
# explicit lagged columns (ESTIMATOR = BAYES), residual covariance = Sigma.
# Run: Rscript tests/testthat/fixtures/mplus/generate-mplus-var.R
suppressWarnings(suppressMessages(library(MplusAutomation)))
.args <- commandArgs(trailingOnly = FALSE)
.file <- sub("^--file=", "", .args[grep("^--file=", .args)])
FIX_DIR <- if (length(.file) == 1L && nzchar(.file)) {
  dirname(normalizePath(.file))
} else {
  "/Users/mohammedsaqr/Documents/Github/idiographic/tests/testthat/fixtures/mplus"
}

sim_one_var <- function(n_t, Phi, Theta, cc, seed) {
  set.seed(seed); p <- nrow(Phi); L <- t(chol(Theta))
  Y <- matrix(0, n_t, p)
  for (t in 2:n_t) Y[t, ] <- cc + Phi %*% Y[t - 1, ] + as.numeric(L %*% rnorm(p))
  Y
}

run_var_fixture <- function(tag, n_t, Phi, Theta, cc, seed) {
  vars <- c("V1", "V2")
  Yraw <- sim_one_var(n_t, Phi, Theta, cc, seed)
  Ys <- scale(Yraw)                                    # match scale = TRUE
  cur <- Ys[-1, , drop = FALSE]; lg <- Ys[-n_t, , drop = FALSE]
  dat <- data.frame(V1 = cur[, 1], V2 = cur[, 2], V1L = lg[, 1], V2L = lg[, 2])

  wd <- file.path("/tmp/mp", paste0("gvfx_", tag))
  dir.create(wd, recursive = TRUE, showWarnings = FALSE)
  write.table(dat, file.path(wd, "m.dat"), row.names = FALSE, col.names = FALSE)
  writeLines(c(
    paste0("TITLE: var ", tag),
    "DATA: FILE = m.dat;",
    "VARIABLE: NAMES = V1 V2 V1L V2L; USEVARIABLES = V1 V2 V1L V2L;",
    "ANALYSIS: ESTIMATOR = BAYES; PROCESSORS = 1; BITERATIONS = (10000); CHAINS = 2;",
    "MODEL:", "  V1 ON V1L V2L;", "  V2 ON V1L V2L;", "  V1 WITH V2;",
    "OUTPUT: TECH1 TECH8;"), file.path(wd, "m.inp"))
  old <- setwd(wd); runModels("m.inp", showOutput = FALSE); setwd(old)

  m <- readModels(file.path(wd, "m.out"), quiet = TRUE)
  pu <- m$parameters$unstandardized
  vi <- function(v) match(v, vars)
  B <- Bsd <- matrix(0, 2, 2, dimnames = list(vars, vars))
  S <- matrix(0, 2, 2, dimnames = list(vars, vars))
  for (r in seq_len(nrow(pu))) {
    h <- pu$paramHeader[r]; pa <- pu$param[r]; e <- pu$est[r]
    if (grepl("\\.ON$", h)) {
      B[vi(sub("\\.ON$", "", h)), vi(sub("L$", "", pa))] <- e
      Bsd[vi(sub("\\.ON$", "", h)), vi(sub("L$", "", pa))] <- pu$posterior_sd[r]
    } else if (h == "Residual.Variances") S[vi(pa), vi(pa)] <- e
    else if (grepl("\\.WITH$", h)) { a <- vi(sub("\\.WITH$", "", h)); b <- vi(pa)
      S[a, b] <- S[b, a] <- e }
  }
  # data for build_var_bayes: a single-subject frame of the standardized series
  sdat <- data.frame(V1 = Ys[, 1], V2 = Ys[, 2])
  fixture <- list(tag = tag, data = sdat, vars = vars,
                  mplus = list(B = B, B_sd = Bsd, Sigma = S),
                  sim = list(Phi = Phi, Theta = Theta, cc = cc, n_t = n_t,
                             seed = seed),
                  meta = list(estimator = "Mplus BAYES VAR (v9 DEMO)"))
  saveRDS(fixture, file.path(FIX_DIR, paste0("var_", tag, ".rds")))
  cat(sprintf("[%s] B=[[%.3f,%.3f],[%.3f,%.3f]] S=[%.3f,%.3f;%.3f] saved\n",
              tag, B[1,1], B[1,2], B[2,1], B[2,2], S[1,1], S[1,2], S[2,2]))
  invisible(fixture)
}

Ph <- function(a,b,c,d) matrix(c(a,b,c,d), 2, 2, byrow = TRUE)
Th <- function(r) matrix(c(1, r, r, 1), 2, 2)
run_var_fixture("base",   200, Ph(.45,.20,-.15,.35), Th(.35), c(.5,-.3), 321)
run_var_fixture("weak",   150, Ph(.25,.05, .10,.20), Th(.10), c(0,0),    11)
run_var_fixture("strong", 250, Ph(.55,.25, .30,.50), Th(.45), c(-.2,.4), 88)
cat("ALL VAR FIXTURES DONE\n")
