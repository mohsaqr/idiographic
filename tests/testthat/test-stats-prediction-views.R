prediction_view_fixture <- function() {
  set.seed(180)
  d <- data.frame(id = rep(c("a", "b", "c"), each = 40),
                  day = rep(seq_len(40), 3), x = rnorm(120), z = rnorm(120))
  d$y <- rep(c(1, 2, -1), each = 40) * d$x + d$z + rnorm(120)
  fit_ml(d, y = "y", x = c("x", "z"), id = "id", time = "day",
         scope = "both", model = c("mean", "ridge", "knn"))
}

test_that("paired comparisons agree with direct prediction-error calculations", {
  fit <- prediction_view_fixture()
  out <- compare_predictions(fit, model = "ridge")
  expect_equal(nrow(out), 3L)
  expect_s3_class(out, "data.frame")
  invisible(lapply(out$subject, function(who) {
    p <- predictions(fit, model = "ridge", scope = "pooled", subject = who)
    i <- predictions(fit, model = "ridge", scope = "individual", subject = who)
    expected <- sqrt(mean((p$observed - p$predicted)^2)) -
      sqrt(mean((i$observed - i$predicted)^2))
    expect_equal(out$gain[out$subject == who], expected)
  }))
  base <- compare_predictions(fit, reference = "mean", model = "ridge")
  expect_equal(base$reference_value,
               metrics(fit, scope = "individual", model = "mean", subject = base$subject)$rmse)
  r2 <- compare_predictions(fit, metric = "r_squared", model = "ridge")
  expect_equal(r2$gain, r2$value - r2$reference_value)
  bad <- fit
  hit <- which(bad$predictions$scope == "individual" & bad$predictions$model == "ridge")[1]
  bad$predictions$row[hit] <- bad$predictions$row[hit] + 1000L
  expect_error(compare_predictions(bad, model = "ridge"), "identical test observations")
  expect_error(compare_predictions(fit, scope = "pooled"), "individual or subgroup")
  expect_error(compare_predictions(fit, metric = "absent"), "numeric metric")
})

test_that("importance summaries retain ties and count people rather than rows", {
  tab <- expand.grid(subject = c("a", "b"), variable = c("x", "z", "w"),
                     stringsAsFactors = FALSE)
  tab$scope <- "individual"
  tab$model <- "ridge"
  tab$estimator <- "native"
  tab$subgroup <- ".none"
  tab$importance <- c(3, 1, 3, 2, 0, 4)
  frequency <- summarize_importance(tab, by = "frequency", top_n = 1)
  expect_equal(frequency$count[match(c("x", "z", "w"), frequency$variable)], c(1, 1, 1))
  expect_equal(frequency$percent, rep(50, 3))
  expect_equal(frequency$n_subjects, rep(2L, 3))
  means <- summarize_importance(tab, by = "mean")
  oracle <- aggregate(importance ~ variable, tab, mean)
  expect_equal(means$importance, oracle$importance[match(means$variable, oracle$variable)])
  expect_error(summarize_importance(rbind(tab, tab[1, ])), "one row per person")
  expect_equal(nrow(summarize_importance(tab, subject = "absent")), 0L)
  tab$importance[1] <- NA_real_
  expect_error(summarize_importance(tab), "finite")
})

test_that("fold metrics are recomputed within folds and respect filters", {
  fit <- prediction_view_fixture()
  d <- fit$data
  rolling <- fit_rolling(d, y = "y", x = c("x", "z"), id = "id", time = "day",
                         method = "ml", model = "ridge", scope = "both",
                         initial = 28, assess = 4, folds = 3)
  tab <- metrics(rolling, by = "fold", scope = "individual", subject = "a")
  expect_equal(tab$fold, 1:3)
  pred <- predictions(rolling, scope = "individual", subject = "a")
  direct <- aggregate(residual ~ fold, pred, function(z) sqrt(mean(z^2)))
  expect_equal(tab$rmse, direct$residual)
  expect_equal(tab$n, rep(4L, 3))
  overall <- metrics(rolling, by = "fold", overall = TRUE)
  expect_true(all(overall$subject == ".overall"))
  expect_equal(nrow(overall), 6L)
  expect_equal(metrics(rolling), rolling$metrics)
  expect_error(metrics(fit, by = "fold"), "rolling fit")
  grDevices::pdf(tempfile(fileext = ".pdf"), width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_equal(nrow(plot_metrics(rolling, type = "time")), 18L)
})

test_that("reflected densities preserve probability mass at metric boundaries", {
  integrate_curve <- function(x) sum(diff(x$value) *
    (utils::head(x$density, -1) + utils::tail(x$density, -1)) / 2)
  low <- idiographic:::.idio_density_curves(c(0, 0.05, 0.2, 0.3), rep("a", 4), lower = 0)
  high <- idiographic:::.idio_density_curves(c(-0.2, 0.8, 0.95, 1), rep("a", 4), upper = 1)
  expect_equal(min(low$value), 0)
  expect_equal(max(high$value), 1)
  expect_lt(min(high$value), 0)
  expect_equal(integrate_curve(low), 1, tolerance = 0.005)
  expect_equal(integrate_curve(high), 1, tolerance = 0.005)
  single <- idiographic:::.idio_density_curves(0, "a", lower = 0)
  expect_true(all(is.finite(single$density)))
  expect_error(idiographic:::.idio_density_curves(1, "a", bandwidth = 0), "positive")
})

test_that("plot variants return the same tidy quantities as their accessors", {
  fit <- prediction_view_fixture()
  set.seed(10)
  imp <- importance(fit, model = c("ridge", "knn"), method = "permutation", repeats = 2)
  grDevices::pdf(tempfile(fileext = ".pdf"), width = 12, height = 10)
  on.exit(grDevices::dev.off(), add = TRUE)
  invisible(lapply(c("boxplot", "density"), function(type) {
    shown <- plot_metrics(fit, scope = "individual", metric = c("rmse", "r_squared"), type = type)
    expect_equal(nrow(shown), 9L)
    expect_true(all(shown$scope == "individual"))
    expect_s3_class(plot_importance(imp, scope = "individual", type = type), "data.frame")
  }))
  profile <- plot_importance(imp, scope = "individual", type = "person", n = 1)
  expect_equal(nrow(profile), 6L)
  expected_top <- aggregate(importance ~ model + subject,
                            subset(imp, scope == "individual"), max)
  paired <- merge(profile, expected_top, by = c("model", "subject"))
  expect_equal(paired$importance.x, paired$importance.y)
  freq <- plot_importance(imp, scope = "individual", type = "frequency", n = 1)
  expect_equal(freq, summarize_importance(imp, scope = "individual", by = "frequency", top_n = 1))
  means <- plot_importance(imp, type = "comparison")
  expect_equal(nrow(means), 8L)
  invisible(lapply(c("points", "density"), function(type) {
    shown <- plot_subjects(fit, reference = "pooled", type = type)
    expected <- compare_predictions(fit)
    expect_equal(shown$gain[order(shown$subject, shown$model)],
                 expected$gain[order(expected$subject, expected$model)])
  }))
  expect_equal(nrow(plot_subjects(fit, reference = "mean")), 9L)
  expect_s3_class(plot_importance(imp, model = "ridge"), "data.frame")
  expect_true(all(models(estimator = "native")$estimator == "native"))
})

test_that("prediction vignette uses public verbs rather than result plumbing", {
  path <- testthat::test_path("..", "..", "vignettes", "prediction.Rmd")
  skip_if_not(file.exists(path))
  lines <- readLines(path)
  code <- character()
  inside <- FALSE
  skip_setup <- FALSE
  invisible(lapply(lines, function(line) {
    if (grepl("^```\\{r", line)) {
      inside <<- TRUE
      skip_setup <<- grepl("^```\\{r setup", line)
    } else if (grepl("^```", line)) {
      inside <<- FALSE
    } else if (inside && !skip_setup) code <<- c(code, line)
  }))
  expect_false(any(grepl("\\[|\\$|\\bfor\\s*\\(|\\b(order|aggregate|reshape|ave|merge)\\s*\\(",
                         code, perl = TRUE)))
  expect_silent(parse(text = code))
})
