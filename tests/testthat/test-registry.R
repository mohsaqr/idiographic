test_that("built-in registry covers every estimator and workflow entry point", {
  registered <- list_estimators()
  expect_s3_class(registered, "data.frame")
  expect_named(
    registered,
    c("name", "kind", "function_name", "aliases", "result_class",
      "available", "description")
  )

  expected_estimators <- c(
    "var", "var_each", "var_bayes", "graphical_var",
    "graphical_var_each", "mlvar", "mlvar_bayes", "mlvar_mplus",
    "usem", "gimme", "rolling_var", "rolling_graphical_var", "ml"
  )
  expected_workflows <- c("preprocess", "stability", "compare", "forecast")
  expect_setequal(
    registered$name[registered$kind == "estimator"], expected_estimators
  )
  expect_setequal(
    registered$name[registered$kind == "workflow"], expected_workflows
  )
  expect_true(all(registered$available))
  expect_true(all(nzchar(registered$description)))
})

test_that("package-wide equivalence ledger has no unassessed built-in methods", {
  ledger <- equivalence_table()
  registered <- list_estimators()
  expect_s3_class(ledger, "data.frame")
  expect_setequal(ledger$method, registered$name)
  expect_named(
    ledger,
    c("method", "kind", "status", "evidence_status", "reference",
      "tolerance_min", "tolerance_max", "scope", "notes")
  )
  expect_false(any(ledger$evidence_status == "open"))
  expect_false(any(ledger$status %in% c("unknown", "not_assessed")))
  expect_true(all(nzchar(ledger$scope)))
  expect_identical(nrow(ledger), 17L)
  expect_identical(
    as.integer(table(factor(ledger$evidence_status,
                            levels = c("closed", "bounded", "conditional")))),
    c(14L, 2L, 1L)
  )
  expect_identical(equivalence_table("ols")$method, "var")
  expect_identical(equivalence_table("mplus")$evidence_status, "conditional")
})

test_that("argument ledger classifies every current public formal exactly once", {
  ledger <- argument_coverage()
  expect_s3_class(ledger, "data.frame")
  expect_named(ledger, c("method", "kind", "argument", "status",
                         "reference", "scope"))
  expect_false(any(ledger$status == "unassessed"))
  expect_identical(nrow(ledger), 315L)
  expect_identical(anyDuplicated(ledger[c("method", "argument")]), 0L)
  expect_true(all(nzchar(ledger$scope)))

  for (method in list_estimators()$name) {
    expected <- names(formals(get_estimator(method)))
    observed <- ledger$argument[ledger$method == method]
    expect_setequal(observed, expected)
  }
  expect_identical(
    argument_coverage("gimme")$status[
      argument_coverage("gimme")$argument == "subgroup"],
    "explicit_rejection"
  )
  expect_identical(
    argument_coverage("mlvar")$status[
      argument_coverage("mlvar")$argument == "temporal"],
    "mode_dependent"
  )
  expect_identical(
    idiographic:::.ido_argument_status("future_argument",
                                       estimator_info("var")),
    "unassessed"
  )
})

test_that("get_estimator returns functions while estimator_info returns metadata", {
  expect_identical(get_estimator("var"), fit_var)
  expect_identical(get_estimator("OLS-VAR"), fit_var)
  expect_identical(get_estimator("fit.var"), fit_var)
  expect_identical(get_estimator("GVAR"), fit_graphical_var)
  expect_identical(get_estimator("DSEM"), fit_mlvar_bayes)
  expect_identical(get_estimator("Mplus DSEM"), fit_mlvar_mplus)
  expect_identical(get_estimator("idiographic ml"), fit_ml)
  expect_identical(get_estimator("estimate-stability"), estimate_stability)

  info <- estimator_info("graphicalVAR")
  expect_type(info, "list")
  expect_true(is.function(get_estimator("graphicalVAR")))
  expect_identical(info$name, "graphical_var")
  expect_identical(info$kind, "estimator")
  expect_identical(info$result_class, "gvar_result")
  expect_identical(info$equivalence$reference, "graphicalVAR::graphicalVAR")

  expect_error(get_estimator("not a real method"),
               "Unknown idiographic method")
  expect_error(estimator_info(character()), "one non-empty character string")
})

test_that("custom estimators can be registered, overwritten, and removed", {
  f1 <- function(data, value = 1) value
  f2 <- function(data, value = 2) value

  on.exit(remove_estimator("registry_test", missing_ok = TRUE), add = TRUE)
  on.exit(remove_estimator("registry_other", missing_ok = TRUE), add = TRUE)

  added <- register_estimator(
    "Registry Test", f1,
    aliases = c("reg-test", "REG.TEST"),
    description = "A test estimator",
    result_class = "registry_test_result"
  )
  expect_identical(added$name, "registry_test")
  expect_identical(get_estimator("reg test"), f1)
  expect_true("registry_test" %in% list_estimators("estimator")$name)

  expect_error(
    register_estimator("registry_test", f2),
    "already registered"
  )
  expect_error(
    register_estimator("registry_other", f2, aliases = "reg_test"),
    "Alias conflict"
  )
  expect_error(
    register_estimator("gvar", f2),
    "alias of `graphical_var`"
  )

  register_estimator(
    "registry_test", f2, aliases = "new-registry-alias",
    overwrite = TRUE
  )
  expect_identical(get_estimator("registry_test"), f2)
  expect_identical(get_estimator("new registry alias"), f2)
  expect_error(get_estimator("reg-test"), "Unknown idiographic method")

  removed <- remove_estimator("new-registry-alias")
  expect_identical(removed$name, "registry_test")
  expect_error(get_estimator("registry_test"), "Unknown idiographic method")
  expect_null(remove_estimator("registry_test", missing_ok = TRUE))
  expect_error(remove_estimator("registry_test"), "No estimator is registered")
})

test_that("local function-name registrations are captured as callable closures", {
  registry_local_fit <- function(data, value = 7) value
  register_estimator("registry_local", "registry_local_fit")
  on.exit(remove_estimator("registry_local", missing_ok = TRUE), add = TRUE)

  expect_identical(get_estimator("registry_local"), registry_local_fit)
  expect_identical(
    as.numeric(fit_idiographic(data.frame(a = 1), "registry_local")), 7
  )
})

test_that("custom registration validates metadata and collisions", {
  f <- function(data) data

  expect_error(register_estimator("", f), "non-empty character string")
  expect_error(register_estimator("registry_bad_fit", 1), "`fit` must be")
  expect_error(register_estimator("registry_bad_signature", function(x) x),
               "must accept a `data` argument")
  expect_error(register_estimator("registry_bad_alias", f, aliases = NA_character_),
               "`aliases` must be")
  expect_error(register_estimator("registry_bad_kind", f, kind = "other"),
               "arg")
  expect_error(register_estimator("registry_bad_class", f, result_class = ""),
               "`result_class` must")
  expect_error(register_estimator("registry_bad_equiv", f,
                                  equivalence = list("partial")),
               "`equivalence` must be a named list")
})

test_that("fit_idiographic dispatches direct and replayable parameter lists", {
  mock_fit <- function(data, x = 0, y = 0) {
    structure(list(value = nrow(data) + x + y), class = "registry_mock_result")
  }
  register_estimator(
    "registry_dispatch", mock_fit,
    aliases = "dispatch mock",
    result_class = "registry_mock_result",
    equivalence = list(
      status = "validated", reference = "mock::reference",
      scope = "Test scope", tolerance = 1e-6
    )
  )
  on.exit(remove_estimator("registry_dispatch", missing_ok = TRUE), add = TRUE)

  d <- data.frame(a = 1:3)
  direct <- fit_idiographic(d, "dispatch-mock", x = 2, y = 4)
  replay <- fit_idiographic(
    d, "registry_dispatch", params = list(x = 2, y = 4)
  )
  mixed <- fit_idiographic(
    d, "registry_dispatch", x = 2, params = list(y = 4)
  )

  expect_identical(direct$value, 9)
  expect_identical(replay$value, direct$value)
  expect_identical(mixed$value, direct$value)
  expect_identical(attr(direct, "idiographic_method"), "registry_dispatch")
  expect_identical(attr(direct, "idiographic_dispatch")$requested_method,
                   "dispatch-mock")
  expect_setequal(attr(direct, "idiographic_dispatch")$argument_names,
                  c("x", "y"))
  stored <- attr(direct, "idiographic_dispatch")$params
  replay_stored <- fit_idiographic(d, "registry_dispatch", params = stored)
  expect_identical(replay_stored$value, direct$value)
})

test_that("fit_idiographic rejects ambiguous or malformed argument sets", {
  mock_fit <- function(data, x = 0) x
  register_estimator("registry_args", mock_fit)
  on.exit(remove_estimator("registry_args", missing_ok = TRUE), add = TRUE)
  d <- data.frame(a = 1)

  expect_error(
    fit_idiographic(d, "registry_args", x = 1, params = list(x = 1)),
    "supplied both directly"
  )
  expect_error(
    fit_idiographic(d, "registry_args", x = 1, x = 2),
    "duplicate argument name"
  )
  expect_error(
    fit_idiographic(d, "registry_args", 1),
    "must be fully named"
  )
  expect_error(
    fit_idiographic(d, "registry_args", params = list(1)),
    "must be fully named"
  )
  expect_error(
    fit_idiographic(d, "registry_args", params = NULL),
    "must be a list"
  )
  expect_error(
    fit_idiographic(d, "registry_args", params = list(data = d)),
    "reserved argument"
  )
})

test_that("unified VAR dispatch preserves estimator results", {
  set.seed(501)
  d <- data.frame(A = rnorm(100), B = rnorm(100))
  direct <- fit_var(d, vars = c("A", "B"), scale = FALSE)
  unified <- fit_idiographic(
    d, "ols", params = list(vars = c("A", "B"), scale = FALSE)
  )

  expect_s3_class(unified, "var_result")
  expect_equal(attr(unified, "model")$temporal,
               attr(direct, "model")$temporal, tolerance = 0)
  expect_equal(attr(unified, "model")$PCC,
               attr(direct, "model")$PCC, tolerance = 0)
})

test_that("equivalence reports attached and registry-inferred declarations", {
  mock_fit <- function(data) {
    structure(list(ok = TRUE), class = "registry_equivalence_result")
  }
  register_estimator(
    "registry_equivalence", mock_fit,
    result_class = "registry_equivalence_result",
    equivalence = list(
      status = "partial", reference = "competitor::fit",
      scope = "A deliberately narrow test scope", tolerance = 0.01,
      notes = "No blanket claim."
    )
  )
  on.exit(remove_estimator("registry_equivalence", missing_ok = TRUE), add = TRUE)

  via_dispatch <- fit_idiographic(data.frame(a = 1), "registry_equivalence")
  attached <- equivalence(via_dispatch)
  expect_s3_class(attached, "idiographic_equivalence")
  expect_identical(attached$method, "registry_equivalence")
  expect_identical(attached$status, "partial")
  expect_identical(attached$source, "dispatch")

  inferred <- equivalence(mock_fit(data.frame(a = 1)))
  expect_identical(inferred$method, "registry_equivalence")
  expect_identical(inferred$source, "result_class")
  expect_identical(inferred$tolerance, 0.01)

  # More-specific child classes win over registered parent classes.
  bayes_child <- structure(list(), class = c("net_mlvar_bayes", "net_mlvar"))
  expect_identical(equivalence(bayes_child)$method, "mlvar_bayes")
  mplus_child <- structure(list(), class = c("net_mplus", "net_mlvar"))
  expect_identical(equivalence(mplus_child)$method, "mlvar_mplus")

  unknown <- equivalence(structure(list(), class = "not_registered"))
  expect_identical(unknown$status, "unknown")
  expect_true(is.na(unknown$method))
  expect_output(print(attached), "Method:    registry_equivalence")
})

test_that("direct built-in fits receive registry-declared equivalence by class", {
  set.seed(502)
  d <- data.frame(A = rnorm(80), B = rnorm(80))
  fit <- fit_var(d, vars = c("A", "B"), scale = FALSE)
  eq <- equivalence(fit)

  expect_identical(eq$method, "var")
  expect_identical(eq$status, "validated")
  expect_identical(eq$reference, "stats::lm.fit")
  expect_identical(eq$source, "result_class")
})

test_that("equivalence declarations distinguish validated and extension slices", {
  set.seed(503)
  d <- data.frame(A = rnorm(100), B = rnorm(100), C = rnorm(100))
  multi_gvar <- fit_graphical_var(
    d, vars = c("A", "B", "C"), lags = c(1, 2),
    lambda_beta = .1, lambda_kappa = .1, n_lambda = 3
  )
  expect_identical(equivalence(multi_gvar)$status, "supported_extension")
  expect_true(is.na(equivalence(multi_gvar)$tolerance))

  panel <- synth_panel(n_id = 8, days = 2, beeps = 10, seed = 503)
  random_mlvar <- suppressWarnings(fit_idiographic(
    panel, "mlvar", vars = c("A", "B", "C"), id = "id", day = "day",
    beep = "beep", temporal = "correlated"
  ))
  expect_identical(equivalence(random_mlvar)$status, "validated")
  expect_match(equivalence(random_mlvar)$scope, "correlated")
  expect_identical(equivalence(random_mlvar)$source, "dispatch")
})
