.fixture_equivalence_panel <- function(n_id = 12, days = 4, beeps = 8,
                                       vars = c("A", "B", "C"),
                                       seed = 1401) {
  set.seed(seed)
  p <- length(vars)
  rows <- lapply(seq_len(n_id), function(i) {
    n_t <- days * beeps
    ri <- stats::rnorm(p, 0, 0.4)
    e <- matrix(stats::rnorm(n_t * p), ncol = p)
    for (t in 2:n_t) {
      e[t, ] <- c(
        0.32 * e[t - 1L, 1L] - 0.15 * e[t - 1L, 2L],
        0.18 * e[t - 1L, 1L] + 0.28 * e[t - 1L, 2L],
        -0.12 * e[t - 1L, 2L] + 0.25 * e[t - 1L, 3L]
      ) + e[t, ]
    }
    m <- as.data.frame(sweep(e, 2L, ri, "+"))
    names(m) <- vars
    m$id <- i
    m$day <- rep(seq_len(days), each = beeps)
    m$beep <- rep(seq_len(beeps), days)
    m
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

.fixture_equivalence_series <- function(n_t = 120, vars = c("A", "B", "C"),
                                        seed = 2402) {
  set.seed(seed)
  p <- length(vars)
  e <- matrix(stats::rnorm(n_t * p), ncol = p)
  for (t in 2:n_t) {
    e[t, ] <- c(
      0.34 * e[t - 1L, 1L] - 0.10 * e[t - 1L, 2L],
      0.20 * e[t - 1L, 1L] + 0.30 * e[t - 1L, 2L],
      -0.18 * e[t - 1L, 1L] + 0.22 * e[t - 1L, 3L]
    ) + e[t, ]
  }
  m <- as.data.frame(e)
  names(m) <- vars
  m$id <- 1L
  m$day <- rep(seq_len(n_t / 10L), each = 10L)
  m$beep <- rep(seq_len(10L), n_t / 10L)
  m
}
