# The tidy output layer: edges() and as.data.frame() return one-row-per-edge
# data.frames with a consistent schema across all three estimators.

test_that("edges() on a netobject_group is tidy with a network column", {
  d <- synth_single(n_t = 120)
  gv <- fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                      day = "day", beep = "beep", n_lambda = 10, gamma = 0)
  e <- edges(gv)
  expect_s3_class(e, "data.frame")
  expect_named(e, c("network", "from", "to", "weight"))
  expect_true(all(e$network %in% c("temporal", "contemporaneous")))
  # as.data.frame delegates to edges()
  expect_identical(as.data.frame(gv), e)
})

test_that("edges() empty result keeps the schema", {
  # A degenerate-but-valid fit with no surviving edges still returns the columns.
  e <- edges(structure(list(temporal = .ido_wrap(matrix(0, 2, 2,
                              dimnames = list(c("A", "B"), c("A", "B"))),
                              "relative", TRUE)),
                       class = "netobject_group"))
  expect_named(e, c("network", "from", "to", "weight"))
  expect_equal(nrow(e), 0L)
})

test_that("edges(net_mlvar) covers all three networks, predictor->outcome", {
  skip_if_not_installed("lme4")
  d <- synth_panel(n_id = 12, days = 4, beeps = 10, seed = 3)
  fit <- suppressWarnings(fit_mlvar(d, vars = c("A", "B", "C"), id = "id",
                                      day = "day", beep = "beep"))
  e <- edges(fit)
  expect_named(e, c("network", "from", "to", "weight"))
  expect_setequal(unique(e$network),
                  c("temporal", "contemporaneous", "between"))
  # AR self-loops are dropped by default, included on request.
  tnet <- as_netobject(fit)$temporal
  w <- tnet$weights
  expect_equal(nrow(e[e$network == "temporal", ]),
               sum(w != 0 & row(w) != col(w)))             # off-diagonal only
  e_self <- edges(fit, include_self = TRUE)
  expect_equal(nrow(e_self[e_self$network == "temporal", ]), sum(w != 0))
})

test_that("summary() returns a tidy per-network metrics data.frame", {
  d <- synth_single(n_t = 120)
  gv <- fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                      lambda_beta = 0.1, n_lambda = 8)
  s <- summary(gv)
  expect_s3_class(s, "data.frame")
  expect_named(s, c("network", "n_nodes", "n_edges", "density",
                    "mean_abs_weight", "n_positive", "n_negative"))
  expect_setequal(s$network, c("temporal", "contemporaneous"))
  expect_true(all(s$density >= 0 & s$density <= 1))
})

test_that("edges() (no self-loops) and summary() agree on edge counts", {
  # Both route through the single .net_edge_idx() mask, so the per-network edge
  # count from edges() must equal summary()$n_edges (no <= vs < drift).
  d <- synth_single(n_t = 120)
  gv <- fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                      lambda_beta = 0.1, n_lambda = 8)
  s <- summary(gv)
  e <- edges(gv)
  per_net <- vapply(s$network, function(nw) nrow(subset(e, network == nw)),
                    integer(1))
  expect_equal(unname(per_net), s$n_edges)
})

test_that("nodes() is a tidy per-node strength table", {
  d <- synth_single(n_t = 120)
  gv <- fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                      lambda_beta = 0.1, n_lambda = 8)
  nd <- nodes(gv)
  expect_named(nd, c("network", "node", "strength", "out_strength",
                     "in_strength", "self"))
  expect_true(all(nd$strength >= 0))
  # undirected (contemporaneous) has NA in/out strength
  expect_true(all(is.na(nd$out_strength[nd$network == "contemporaneous"])))
  expect_false(any(is.na(nd$out_strength[nd$network == "temporal"])))
  # `self` (autoregression) is reported separately from strength, never NA
  expect_false(any(is.na(nd$self)))
})

test_that("coefs() is tidy: full table for gvar, per-person for gimme", {
  skip_on_cran()
  d <- synth_single(n_t = 120)
  gv <- fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                      lambda_beta = 0.1, n_lambda = 8)
  cg <- coefs(gv)
  expect_named(cg, c("network", "from", "to", "weight"))
  # full table includes every temporal pair (p*p) including AR diagonal
  expect_equal(sum(cg$network == "temporal"), 9L)

  skip_if_not_installed("lavaan")
  d2 <- synth_panel(n_id = 5, days = 3, beeps = 12, vars = c("A", "B"), seed = 6)
  gm <- fit_gimme(d2, vars = c("A", "B"), id = "id",
                    day = "day", beep = "beep", seed = 1)
  cgm <- coefs(gm)
  expect_named(cgm, c("subject", "network", "from", "to", "weight"))
  expect_true(all(cgm$subject %in% as.character(unique(d2$id))))
})

test_that("edges(net_gimme) is tidy with network + level", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 5, days = 3, beeps = 12, vars = c("A", "B"), seed = 6)
  gm <- fit_gimme(d, vars = c("A", "B"), id = "id",
                    day = "day", beep = "beep", seed = 1)
  e <- edges(gm)
  expect_named(e, c("network", "from", "to", "weight", "level"))
  expect_true(all(e$network %in% c("temporal", "contemporaneous")))
  expect_true(all(e$level %in% c("group", "individual")))
  # autoregression (self-loops) included by default for GIMME
  expect_true(any(e$from == e$to))
  # ... and droppable
  e2 <- edges(gm, include_self = FALSE)
  expect_false(any(e2$from == e2$to))
})

test_that("edges(network=, n=) filters layers, keeps top-n, handles empty layers", {
  d <- synth_panel(n_id = 1, days = 4, beeps = 30, vars = c("A", "B", "C"),
                   seed = 11)
  fit <- fit_var(d, vars = c("A", "B", "C"), id = "id", day = "day",
                 beep = "beep")

  te <- edges(fit, network = "temporal")
  expect_true(all(te$network == "temporal"))
  expect_equal(nrow(edges(fit, network = "temporal", n = 2)), 2L)
  # a genuine but empty canonical layer yields 0 rows, not an error
  empty <- edges(fit, network = "between")
  expect_s3_class(empty, "data.frame")
  expect_equal(nrow(empty), 0L)
  # a typo is still an error
  expect_error(edges(fit, network = "temporl"), "Unknown network layer")
})

test_that("person-specific VAR lists stack the tidy accessor contract", {
  d <- synth_panel(n_id = 3, days = 3, beeps = 12, seed = 55)
  fits <- fit_var_each(d, vars = c("A", "B", "C"), id = "id",
                      day = "day", beep = "beep", scale = FALSE)
  expect_s3_class(summary(fits), "data.frame")
  expect_true("subject" %in% names(summary(fits)))
  expect_true("subject" %in% names(edges(fits)))
  expect_true("subject" %in% names(nodes(fits)))
  expect_identical(as.data.frame(fits), coefs(fits))
})
