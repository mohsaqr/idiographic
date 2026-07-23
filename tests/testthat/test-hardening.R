test_that("registry rejects malformed metadata and unavailable functions", {
  empty <- list_estimators(kind = character())
  expect_s3_class(empty, "data.frame")
  expect_equal(nrow(empty), 0L)
  expect_error(estimator_info("---"), "usable method name")

  expect_error(register_estimator("bad-alias", function(data) data,
                                  aliases = NA_character_), "aliases")
  expect_error(register_estimator("bad-class", function(data) data,
                                  result_class = ""), "result_class")
  expect_error(register_estimator("bad-description", function(data) data,
                                  description = NA_character_), "description")
  expect_error(register_estimator(
    "bad-fields", function(data) data,
    equivalence = structure(list("x", "y"), names = c("status", "status"))
  ), "duplicate fields")
  expect_error(register_estimator(
    "reserved-fields", function(data) data,
    equivalence = list(method = "mine")
  ), "reserved field")

  invalid_declarations <- list(
    list(status = NA_character_),
    list(reference = c("a", "b")),
    list(scope = ""),
    list(tolerance = -1),
    list(notes = NA_character_)
  )
  for (i in seq_along(invalid_declarations)) {
    expect_error(register_estimator(
      paste0("bad-declaration-", i), function(data) data,
      equivalence = invalid_declarations[[i]]
    ), "equivalence")
  }

  register_estimator("temporarily-unavailable", ".definitely_missing_fit")
  on.exit(remove_estimator("temporarily-unavailable", missing_ok = TRUE), add = TRUE)
  expect_false(estimator_info("temporarily-unavailable")$fit %in% ls())
  expect_false(list_estimators()$available[
    list_estimators()$name == "temporarily_unavailable"
  ])
  expect_error(get_estimator("temporarily-unavailable"), "unavailable function")
})

test_that("equivalence objects remain conservative for unknown configurations", {
  unknown <- equivalence(structure(list(), class = "not_registered"))
  expect_identical(unknown$status, "unknown")
  expect_identical(unknown$source, "unknown")
  expect_output(print(unknown), "Method:    unknown")

  ambiguous <- structure(list(), class = c("net_mlvar", "gvar_result"))
  declaration <- equivalence(ambiguous)
  expect_true(declaration$method %in% c("mlvar", "graphical_var"))
  expect_true(declaration$status %in% c("validated", "supported_extension"))
})

test_that("graphical VAR validates adversarial raw and prepared inputs", {
  d <- synth_single(n_t = 30, vars = c("A", "B"), seed = 901)
  fixed <- list(lambda_beta = 0.1, lambda_kappa = 0.1)
  call_gvar <- function(data = d, ...) {
    args <- utils::modifyList(c(list(data = data, vars = c("A", "B")), fixed),
                              list(...))
    do.call(fit_graphical_var, args)
  }

  expect_error(fit_graphical_var(1:5, vars = c("A", "B")), "data frame")
  expect_error(call_gvar(vars = c("A", "A")), "unique variable")
  expect_error(call_gvar(gamma = Inf), "gamma")
  expect_error(call_gvar(ebic_tol = -1), "ebic_tol")
  expect_error(call_gvar(mimic = NA_character_), "mimic")
  expect_error(call_gvar(lambda_beta = NA_real_), "lambda_beta")
  expect_error(call_gvar(lambda_kappa = -0.1), "lambda_kappa")
  expect_error(call_gvar(regularize_mat_beta = matrix(NA_real_, 2, 2)),
               "regularize_mat_beta")
  expect_error(call_gvar(regularize_mat_beta = matrix(1, 3, 3)),
               "wrong dimensions")
  expect_error(call_gvar(regularize_mat_kappa = matrix(-1, 2, 2)),
               "regularize_mat_kappa")

  cur <- matrix(rnorm(20), 10, 2, dimnames = list(NULL, c("A", "B")))
  lag <- cbind(`(Intercept)` = 1, matrix(rnorm(20), 10, 2))
  expect_error(fit_graphical_var(list(data_c = "bad", data_l = lag),
                                 lambda_beta = 0.1, lambda_kappa = 0.1),
               "matrices or data frames")
  expect_error(fit_graphical_var(list(data_c = cur, data_l = lag[-1, ]),
                                 lambda_beta = 0.1, lambda_kappa = 0.1),
               "same number of rows")
  expect_error(fit_graphical_var(list(data_c = cur[, 1, drop = FALSE],
                                      data_l = lag[, 1:2]),
                                 lags = 1,
                                 lambda_beta = 0.1, lambda_kappa = 0.1),
               "at least two columns")
  bad_intercept <- lag
  bad_intercept[1, 1] <- 0
  expect_error(fit_graphical_var(list(data_c = cur, data_l = bad_intercept),
                                 lambda_beta = 0.1, lambda_kappa = 0.1),
               "intercept of ones")
  no_names <- unname(cur)
  expect_error(fit_graphical_var(list(data_c = no_names, data_l = unname(lag)),
                                 lambda_beta = 0.1, lambda_kappa = 0.1),
               "vars.*required")
  all_missing <- cur
  all_missing[] <- NA_real_
  expect_error(fit_graphical_var(list(data_c = all_missing, data_l = lag),
                                 lambda_beta = 0.1, lambda_kappa = 0.1),
               "No complete lag pairs")
})

test_that("multi-lag graphical beta masks normalize without changing estimates", {
  d <- synth_single(n_t = 60, vars = c("A", "B"), seed = 902)
  mask <- matrix(c(0, 1, 1, 0), 2, 2, byrow = TRUE)
  replicated <- do.call(cbind, rep(list(mask), 2L))
  short <- fit_graphical_var(d, c("A", "B"), lags = c(1, 2),
                             lambda_beta = 0.08, lambda_kappa = 0.08,
                             regularize_mat_beta = mask)
  explicit <- fit_graphical_var(d, c("A", "B"), lags = c(1, 2),
                                lambda_beta = 0.08, lambda_kappa = 0.08,
                                regularize_mat_beta = replicated)
  expect_equal(short$beta, explicit$beta, tolerance = 0)
  expect_equal(short$kappa, explicit$kappa, tolerance = 0)
})

test_that("mlVAR front door rejects silent or ambiguous controls", {
  d <- synth_panel(n_id = 4, days = 2, beeps = 8,
                   vars = c("A", "B"), seed = 903)
  base <- list(data = d, vars = c("A", "B"), id = "id",
               day = "day", beep = "beep")
  call_mlvar <- function(...) {
    do.call(fit_mlvar, utils::modifyList(base, list(...)))
  }

  expect_error(fit_mlvar(as.matrix(d), c("A", "B"), "id"), "data frame")
  expect_error(call_mlvar(vars = c("A", "A")), "unique")
  expect_error(call_mlvar(id = "missing_id"), "Columns not found")
  bad_type <- d
  bad_type$A <- factor(bad_type$A)
  expect_error(fit_mlvar(bad_type, c("A", "B"), "id"), "must be numeric")
  expect_error(call_mlvar(nCores = 1.5), "positive integer")
  expect_error(call_mlvar(compare_to_lags = 2), "include every fitted")
  expect_error(call_mlvar(estimator = "lm", temporal = "fixed"),
               "requires.*unique")
  expect_error(call_mlvar(temporal = "unique"),
               "requires `estimator = \"lm\"`")
  expect_error(call_mlvar(estimator = "lm", temporal = "unique", AR = TRUE),
               "AR = TRUE.*estimator = \"lmer\"")
  expect_error(call_mlvar(engine = "bayes", AR = TRUE),
               "Bayesian engine.*AR")
  expect_error(call_mlvar(engine = "bayes", lags = 2),
               "supports `lags = 1` only")
  expect_error(call_mlvar(engine = "bayes", compare_to_lags = c(1, 2)),
               "Bayesian engine.*compare_to_lags")
  expect_error(call_mlvar(engine = "reference", missing = "model"),
               "only for.*bayes")
  expect_error(call_mlvar(engine = "mplus", lags = 2),
               "supports `lags = 1` only")
  expect_error(call_mlvar(engine = "mplus", temporal = "unique"),
               "does not support.*unique")

  missing_data <- d
  missing_data$A[3] <- NA_real_
  expect_error(fit_mlvar(missing_data, c("A", "B"), "id",
                         engine = "reference", missing = "fail"),
               "Missing model or ordering values")

  missing_key <- d
  missing_key$id[3] <- NA
  expect_error(fit_mlvar(missing_key, c("A", "B"), "id",
                         day = "day", beep = "beep", missing = "fail"),
               "Missing model or ordering values")

  duplicate_key <- rbind(d, d[1, , drop = FALSE])
  expect_error(fit_mlvar(duplicate_key, c("A", "B"), "id",
                         day = "day", beep = "beep"),
               "Duplicate observation keys.*deduplicate explicitly")
})

test_that("true_means validation is complete and upstream-aligned", {
  d <- synth_panel(n_id = 6, days = 2, beeps = 8,
                   vars = c("A", "B"), seed = 904)
  means <- stats::aggregate(d[c("A", "B")], list(id = d$id), mean)
  args <- list(data = d, vars = c("A", "B"), id = "id",
               day = "day", beep = "beep")

  expect_error(do.call(fit_mlvar, c(args, list(true_means = means[-1, ]))),
               "missing one or more fitted subjects")
  duplicate <- rbind(means, means[1, ])
  expect_error(do.call(fit_mlvar, c(args, list(true_means = duplicate))),
               "one row per subject")
  nonnumeric <- means
  nonnumeric$A <- as.character(nonnumeric$A)
  expect_error(do.call(fit_mlvar, c(args, list(true_means = nonnumeric))),
               "must be numeric")
})

test_that("GIMME validates scalar controls and stable output dimensions", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 3, days = 1, beeps = 12,
                   vars = c("A", "B"), seed = 905)
  base <- list(data = d, vars = c("A", "B"), id = "id")
  call_gimme <- function(...) {
    do.call(fit_gimme, utils::modifyList(base, list(...)))
  }

  expect_error(fit_gimme(as.matrix(d), c("A", "B"), "id"), "data frame")
  expect_error(call_gimme(vars = c("A", "A")), "unique")
  expect_error(call_gimme(groupcutoff = Inf), "groupcutoff")
  expect_error(call_gimme(n_excellent = 1.5), "whole number")
  expect_error(call_gimme(seed = NA_real_), "seed")
  expect_error(call_gimme(plot = 1), "plot")
  expect_error(call_gimme(paths = NA_character_), "paths")
  expect_error(call_gimme(exogenous = c("A", "A")), "unique")
  expect_error(call_gimme(subgroup = 1), "subgroup")

  fit <- suppressMessages(call_gimme(seed = 1))
  expect_true(all(vapply(fit$coefs, function(x) identical(dim(x), c(2L, 4L)),
                         logical(1))))
  expect_true(all(vapply(fit$psi, function(x) identical(dim(x), c(2L, 4L)),
                         logical(1))))
  extension <- fit
  extension$config$alpha <- 0.07
  expect_identical(equivalence(extension)$status, "supported_extension")
  expect_true(is.na(equivalence(extension)$tolerance))
})

test_that("GIMME weakest-path pruning handles empty, weak, and strong inputs", {
  expect_identical(.gimme_find_weakest(list(NA), "A~B", 0.75, 1, 1.96),
                   NA_character_)
  expect_identical(.gimme_find_weakest(list(data.frame()), "A~B", 0.75, 1, 1.96),
                   NA_character_)

  z <- data.frame(
    lhs = rep(c("A", "B"), each = 3),
    op = "~",
    rhs = rep(c("B", "A"), each = 3),
    z = c(0.1, 0.2, 0.3, 3.0, 3.1, 3.2)
  )
  expect_identical(.gimme_find_weakest(list(z), "C~D", 0.75, 3, 1.96),
                   NA_character_)
  expect_identical(.gimme_find_weakest(list(z), c("A~B", "B~A"), 0.75, 3, 1.96),
                   "A~B")
  expect_identical(.gimme_find_weakest(list(z[z$lhs == "B", ]), "B~A",
                                       0.75, 3, 1.96),
                   NA_character_)
})

test_that("matrix selectors fail informatively at container boundaries", {
  empty <- structure(list(), class = "var_list")
  expect_error(matrices(empty), "No fitted models")

  d <- synth_panel(n_id = 2, days = 2, beeps = 8,
                   vars = c("A", "B"), seed = 906)
  fits <- fit_var_each(d, c("A", "B"), id = "id", day = "day", beep = "beep")
  expect_error(matrices(fits, subject = "absent"), "Unknown subject")
  expect_error(matrices(fits, subject = 1.5), "name or index")
})
