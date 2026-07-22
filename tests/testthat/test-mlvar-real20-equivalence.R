.mlvar_real20_path <- function(...) {
  testthat::test_path("..", "..", "validation", "fixtures",
                      "mlvar-real20", ...)
}

.mlvar_real20_manifest <- function() {
  utils::read.csv(.mlvar_real20_path("manifest.csv"),
                  colClasses = c(dataset_id = "character"),
                  stringsAsFactors = FALSE)
}

test_that("real-20 mlVAR fixture is complete and records its edge cases", {
  skip_unless_equivalence()
  manifest <- .mlvar_real20_manifest()
  expect_equal(nrow(manifest), 20L)
  expect_equal(length(unique(manifest$dataset_id)), 20L)
  expect_true(all(file.exists(.mlvar_real20_path(
    "data", paste0(manifest$dataset_id, "-data.csv")
  ))))
  expect_true(all(file.exists(.mlvar_real20_path(
    "oracle", paste0(manifest$dataset_id, ".rds")
  ))))
  expect_identical(manifest$dataset_id[manifest$missing_id > 0], "0008")
  expect_setequal(manifest$dataset_id[manifest$between_degenerate],
                  c("0003", "0022"))
  expect_true(all(manifest$duplicate_keys == 0L))
  expect_true(all(manifest$gap_steps > 0L))
  expect_identical(manifest$original_beep_source[
    manifest$dataset_id == "0032"
  ], "counter")
})

test_that("native fixed mlVAR matches mlVAR 0.7.3 on 20 real ESM datasets", {
  skip_unless_equivalence()
  manifest <- .mlvar_real20_manifest()

  for (dataset_id in manifest$dataset_id) {
    oracle <- readRDS(.mlvar_real20_path("oracle",
                                        paste0(dataset_id, ".rds")))
    data <- utils::read.csv(.mlvar_real20_path(
      "data", paste0(dataset_id, "-data.csv")
    ), stringsAsFactors = FALSE)

    fit <- suppressWarnings(fit_mlvar(
      data = data,
      vars = oracle$meta$vars,
      id = "id",
      day = "day",
      beep = "beep",
      lags = 1,
      estimator = "lmer",
      temporal = "fixed",
      contemporaneous = "fixed",
      scale = FALSE
    ))

    expect_equal(attr(fit, "n_obs"), oracle$meta$n_lag_pairs,
                 info = dataset_id)
    expect_equal(fit$temporal$weights, oracle$temporal,
                 tolerance = 1e-8, ignore_attr = TRUE, info = dataset_id)
    expect_equal(fit$contemporaneous$weights, oracle$contemporaneous,
                 tolerance = 1e-8, ignore_attr = TRUE, info = dataset_id)

    finite_between <- upper.tri(oracle$between) & is.finite(oracle$between)
    if (any(finite_between)) {
      expect_equal(fit$between$weights[finite_between],
                   oracle$between[finite_between],
                   tolerance = 1e-8, info = dataset_id)
    } else {
      expect_true(isTRUE(oracle$meta$between_degenerate), info = dataset_id)
      expect_true(all(fit$between$weights[upper.tri(fit$between$weights)] == 0),
                  info = dataset_id)
    }
    expect_identical(equivalence(fit)$status, "validated", info = dataset_id)
  }
})
