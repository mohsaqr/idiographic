# Synthetic-data generators shared by the test suite. Each returns a long-format
# panel with id/day/beep columns plus the named variables, so every estimator
# can be exercised without any external data file.

# Stationary VAR(1) panel with genuine between-person intercepts. `days`/`beeps`
# determine the (id, day) block structure used for within-day lagging.
synth_panel <- function(n_id = 12, days = 4, beeps = 12, vars = c("A", "B", "C"),
                        ar = 0.35, between_sd = 0.5, seed = 1) {
  set.seed(seed)
  p <- length(vars)
  n_t <- days * beeps
  rows <- lapply(seq_len(n_id), function(i) {
    ri <- stats::rnorm(p, 0, between_sd)
    e  <- matrix(stats::rnorm(n_t * p), ncol = p)
    for (t in 2:n_t) e[t, ] <- ar * e[t - 1L, ] + e[t, ]
    m <- as.data.frame(sweep(e, 2, ri, "+"))
    names(m) <- vars
    m$id   <- i
    m$day  <- rep(seq_len(days), each = beeps)
    m$beep <- rep(seq_len(beeps), days)
    m
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  attr(out, "vars") <- vars
  out
}

# Single-subject series (for graphical_var on one person).
synth_single <- function(n_t = 120, vars = c("A", "B", "C"), ar = 0.4, seed = 2) {
  set.seed(seed)
  p <- length(vars)
  e <- matrix(stats::rnorm(n_t * p), ncol = p)
  for (t in 2:n_t) e[t, ] <- ar * e[t - 1L, ] + e[t, ]
  m <- as.data.frame(e)
  names(m) <- vars
  m$id   <- 1L
  m$day  <- rep(seq_len(n_t / 10), each = 10)
  m$beep <- rep(seq_len(10), n_t / 10)
  attr(m, "vars") <- vars
  m
}

# Single-subject planted VAR(1) with known temporal network:
# A <- A_lag, B <- A_lag + B_lag, C <- B_lag + C_lag.
synth_planted_var <- function(days = 12, beeps = 25, seed = 901) {
  set.seed(seed)
  vars <- c("A", "B", "C")
  beta <- matrix(c(0.55,  0.00, 0.00,
                   0.35,  0.45, 0.00,
                   0.00, -0.30, 0.40),
                 nrow = 3, byrow = TRUE,
                 dimnames = list(vars, vars))
  n <- days * beeps
  x <- matrix(0, n, length(vars))
  e <- matrix(stats::rnorm(n * length(vars), sd = 0.45), ncol = length(vars))
  for (t in 2:n) x[t, ] <- beta %*% x[t - 1L, ] + e[t, ]
  out <- as.data.frame(x)
  names(out) <- vars
  out$id <- 1L
  out$day <- rep(seq_len(days), each = beeps)
  out$beep <- rep(seq_len(beeps), days)
  attr(out, "vars") <- vars
  attr(out, "beta") <- beta
  out
}

# Panel planted VAR(1) with common group structure for uSEM/GIMME/mlVAR:
# A <- A_lag, B <- A_lag + B_lag.
synth_planted_panel <- function(n_id = 5, days = 8, beeps = 25, seed = 902,
                                noise_sd = 0.35, between_sd = 0) {
  set.seed(seed)
  vars <- c("A", "B")
  beta <- matrix(c(0.55, 0.00,
                   0.45, 0.45),
                 nrow = 2, byrow = TRUE,
                 dimnames = list(vars, vars))
  rows <- lapply(seq_len(n_id), function(id) {
    n <- days * beeps
    x <- matrix(0, n, length(vars))
    e <- matrix(stats::rnorm(n * length(vars), sd = noise_sd),
                ncol = length(vars))
    for (t in 2:n) x[t, ] <- beta %*% x[t - 1L, ] + e[t, ]
    ri <- stats::rnorm(length(vars), 0, between_sd)
    out <- as.data.frame(sweep(x, 2, ri, "+"))
    names(out) <- vars
    out$id <- id
    out$day <- rep(seq_len(days), each = beeps)
    out$beep <- rep(seq_len(beeps), days)
    out
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  attr(out, "vars") <- vars
  attr(out, "beta") <- beta
  out
}
