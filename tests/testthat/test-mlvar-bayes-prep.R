# Gap-aware + TINTERVAL lag construction in fit_mlvar_bayes's data prep.

test_that("gap-aware lagging skips absent occasions (no spurious lag-1 pair)", {
  # Occasion 3 is absent for each subject: valid lag pairs are (2<-1) and (5<-4),
  # NEVER (4<-2). Values are the occasion number so pairs are easy to verify.
  mk <- function(id) data.frame(id = id, beep = c(1, 2, 4, 5),
                                V1 = c(1, 2, 4, 5), V2 = c(10, 20, 40, 50))
  d <- rbind(mk(1), mk(2), mk(3))
  prep <- .mlvb_prepare(d, vars = c("V1", "V2"), id = "id", day = NULL,
                        beep = "beep", scale = FALSE, scaleWithin = FALSE)
  pp <- prep$persons[[1]]
  expect_equal(nrow(pp$cur), 2L)                       # only the two gap-free pairs
  # lag value must be the immediately preceding occasion, never across the gap
  expect_true(all(pp$cur[, "V1"] - pp$lag[, "V1"] == 1))
  expect_false(any(pp$lag[, "V1"] == 2 & pp$cur[, "V1"] == 4))
})

test_that("consecutive occasions are unaffected (backwards compatible)", {
  d <- do.call(rbind, lapply(1:3, function(id)
    data.frame(id = id, beep = 1:6, V1 = 1:6, V2 = (1:6) * 10)))
  prep <- .mlvb_prepare(d, vars = c("V1", "V2"), id = "id", day = NULL,
                        beep = "beep", scale = FALSE, scaleWithin = FALSE)
  expect_equal(nrow(prep$persons[[1]]$cur), 5L)        # all 5 consecutive pairs
  expect_true(all(prep$persons[[1]]$cur[, "V1"] -
                    prep$persons[[1]]$lag[, "V1"] == 1))
})

test_that("tinterval bins a continuous time column onto a grid", {
  # times ~0.1 apart within three clusters ~1 apart; width 1 -> 3 bins/person.
  mk <- function(id) data.frame(id = id,
    t = c(0.0, 0.1, 1.0, 1.1, 2.0, 2.1),
    V1 = c(1, 1, 2, 2, 3, 3), V2 = c(1, 1, 2, 2, 3, 3))
  d <- rbind(mk(1), mk(2), mk(3))
  prep <- .mlvb_prepare(d, vars = c("V1", "V2"), id = "id", day = NULL,
                        beep = "t", scale = FALSE, scaleWithin = FALSE,
                        tinterval = 1)
  # each (id,bin) collapses to first obs -> 3 occasions, 2 consecutive lag pairs
  expect_equal(nrow(prep$persons[[1]]$cur), 2L)
})

test_that("residual = 'random' requires temporal = 'random'", {
  skip_if_not_installed("corpcor")
  d <- do.call(rbind, lapply(1:10, function(i) {
    y <- matrix(0, 30, 2); for (t in 2:30) y[t, ] <- c(0.3, 0.2) * y[t - 1, ] + rnorm(2)
    data.frame(id = i, beep = 1:30, V1 = y[, 1], V2 = y[, 2])
  }))
  expect_error(
    fit_mlvar_bayes(d, vars = c("V1", "V2"), id = "id", beep = "beep",
                      temporal = "fixed", residual = "random", n_iter = 300),
    "requires temporal")
})
