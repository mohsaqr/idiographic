test_that("build_usem fits fixed uSEM and returns Carm-style tidy outputs", {
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 4, days = 3, beeps = 10, vars = c("A", "B"),
                   seed = 42)
  fit <- build_usem(d, vars = c("A", "B"), id = "id", day = "day",
                    beep = "beep", temporal = "ar",
                    contemporaneous = "none", residual_cov = TRUE)

  expect_s3_class(fit, "net_usem")
  expect_s3_class(fit, "netobject_group")
  expect_s3_class(fit, "cograph_group")
  expect_named(as_netobject(fit), c("temporal", "contemporaneous",
                                    "residual_cov"))
  expect_equal(fit$n_subjects, 4L)
  expect_equal(fit$n_converged, 4L)
  expect_equal(dim(fit$temporal), c(2L, 2L))
  expect_equal(dim(fit$contemporaneous), c(2L, 2L))
  expect_equal(dim(fit$residual_cov), c(2L, 2L))

  e <- edges(fit)
  expect_named(e, c("network", "from", "to", "weight"))
  expect_true(all(e$network %in% c("temporal", "contemporaneous",
                                   "residual_cov")))
  e_self <- edges(fit, include_self = TRUE)
  expect_true(any(e_self$network == "temporal" & e_self$from == e_self$to))

  cf <- coefs(fit)
  expect_named(cf, c("subject", "network", "from", "to", "weight"))
  expect_setequal(cf$network, c("temporal", "contemporaneous", "residual_cov"))
  expect_equal(nrow(subset(cf, network == "temporal")), 4L * 4L)

  nd <- nodes(fit)
  expect_named(nd, c("network", "node", "strength", "out_strength",
                     "in_strength", "self"))
  sm <- summary(fit)
  expect_named(sm, c("network", "n_nodes", "n_edges", "density",
                     "mean_abs_weight", "n_positive", "n_negative"))
})

test_that("build_usem supports all lagged paths and user contemporaneous paths", {
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 3, days = 3, beeps = 12, vars = c("A", "B"),
                   seed = 11)
  fit <- build_usem(d, vars = c("A", "B"), id = "id", day = "day",
                    beep = "beep", temporal = "all",
                    contemporaneous = "B ~ A", residual_cov = FALSE)

  expect_true("A~Alag" %in% fit$syntax)
  expect_true("A~Blag" %in% fit$syntax)
  expect_true("B~Alag" %in% fit$syntax)
  expect_true("B~Blag" %in% fit$syntax)
  expect_true("B ~ A" %in% fit$syntax)
  expect_true(all(diag(fit$residual_cov) == 0))
  expect_true(any(coefs(fit)$network == "contemporaneous"))
})

test_that("build_usem validates path role against dynamic design", {
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 3, days = 2, beeps = 8, vars = c("A", "B"),
                   seed = 12)
  expect_error(
    build_usem(d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
               temporal = "A ~ B"),
    "Invalid `temporal`"
  )
  expect_error(
    build_usem(d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
               contemporaneous = "A ~ Blag"),
    "Invalid `contemporaneous`"
  )
})

test_that("trimmed uSEM is clean-room candidate search over declared paths", {
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 3, days = 3, beeps = 12, vars = c("A", "B"),
                   seed = 14)
  fixed <- build_usem(d, vars = c("A", "B"), id = "id", day = "day",
                      beep = "beep", temporal = "all",
                      contemporaneous = "all", residual_cov = TRUE,
                      trim = FALSE)
  trimmed <- build_usem(d, vars = c("A", "B"), id = "id", day = "day",
                        beep = "beep", temporal = "all",
                        contemporaneous = "all", residual_cov = TRUE,
                        trim = TRUE)

  expect_s3_class(trimmed, "net_usem")
  expect_true(is.list(trimmed$syntax))
  expect_equal(names(trimmed$syntax), names(trimmed$subjects))
  expect_true(all(lengths(trimmed$syntax) <= length(fixed$syntax)))
  expect_true(any(lengths(trimmed$syntax) < length(fixed$syntax)))

  allowed_dynamic <- c("A~Alag", "A~Blag", "B~Alag", "B~Blag", "A~B",
                       "B~A", "A~~B")
  base_or_allowed <- function(paths) {
    canon <- idiographic:::.usem_canon_paths(paths)
    dynamic <- canon[canon %in% idiographic:::.usem_canon_paths(allowed_dynamic)]
    all(dynamic %in% idiographic:::.usem_canon_paths(allowed_dynamic))
  }
  expect_true(all(vapply(trimmed$syntax, base_or_allowed, logical(1))))
  expect_true(trimmed$config$trim)
  expect_named(edges(trimmed), c("network", "from", "to", "weight"))
})
