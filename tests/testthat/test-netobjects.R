test_that("as_netobject.gvar_result preserves plotting method names", {
  skip_on_cran()
  d <- synth_single(n_t = 100)
  gv <- fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                      day = "day", beep = "beep", n_lambda = 8, gamma = 0.5)
  no <- as_netobject(gv)
  expect_s3_class(no, "netobject_group")
  expect_identical(no$temporal$method, "relative")
  expect_identical(no$contemporaneous$method, "co_occurrence")
  expect_true(no$temporal$directed)
  expect_false(no$contemporaneous$directed)
})

test_that("standard estimators are cograph-ready groups from construction", {
  skip_on_cran()
  d <- synth_single(n_t = 100)
  gv <- fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                      day = "day", beep = "beep", n_lambda = 8, gamma = 0)
  expect_s3_class(gv, "netobject_group")
  expect_s3_class(gv, "cograph_group")
  ng <- as_netobject(gv)
  expect_s3_class(ng$temporal, "cograph_network")
  expect_s3_class(ng$temporal, "netobject")
  expect_identical(class(ng$temporal)[1:3],
                   c("cograph_network", "netobject", "list"))
  expect_identical(ng$temporal$method, "relative")
  expect_identical(ng$contemporaneous$method, "co_occurrence")
  expect_equal(dim(gv$temporal), c(3L, 3L))

  vv <- fit_var(d, vars = c("A", "B", "C"), id = "id",
                  day = "day", beep = "beep")
  expect_s3_class(vv, "netobject_group")
  vg <- as_netobject(vv)
  expect_s3_class(vg$temporal, "cograph_network")
  expect_true(vg$temporal$directed)
  expect_false(vg$contemporaneous$directed)

  skip_if_not_installed("cograph")
  tmp <- tempfile(fileext = ".png"); grDevices::png(tmp)
  expect_no_error(cograph::splot(gv))
  expect_no_error(cograph::splot(vv))
  grDevices::dev.off()
})

test_that("as_netobject.cograph_network recovers a nested method", {
  skip_on_cran()
  cn <- structure(
    list(weights = matrix(c(0, 1, 0, 0), 2, 2,
                          dimnames = list(c("A", "B"), c("A", "B"))),
         directed = TRUE,
         meta = list(tna = list(method = "relative"))),
    class = "cograph_network"
  )
  no <- as_netobject(cn)
  expect_identical(no$method, "relative")
})

test_that("matrices() prints compact blocks and returns estimator matrices", {
  skip_on_cran()
  d <- synth_single(n_t = 100, vars = c("A", "B", "C"), seed = 211)

  vv <- fit_var(d, vars = c("A", "B", "C"), id = "id",
                  day = "day", beep = "beep")
  out <- capture.output(vm <- matrices(vv))
  expect_true(any(grepl("^\\$beta$", out)))
  expect_true(any(grepl("^\\$temporal$", out)))
  expect_equal(vm$beta, vv$beta)
  expect_equal(vm$temporal, vv$temporal)
  expect_equal(vm$PCC, vv$PCC)

  out_net <- capture.output(tm <- matrices(vv[["temporal"]]))
  expect_true(any(grepl("^\\$weights$", out_net)))
  expect_equal(tm$weights, vv[["temporal"]]$weights)

  gv <- fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                      day = "day", beep = "beep", n_lambda = 8, gamma = 0)
  out_gv <- capture.output(gm <- matrices(gv))
  expect_true(any(grepl("^\\$PCC$", out_gv)))
  expect_equal(gm$beta, gv$beta)
  expect_equal(gm$PCC, gv$PCC)
})

test_that("matrices() delegates through fit-holding result containers", {
  skip_on_cran()
  d <- synth_single(n_t = 80, vars = c("A", "B", "C"), seed = 212)

  roll <- fit_rolling_var(d, vars = c("A", "B", "C"), id = "id",
                      day = "day", beep = "beep", window_size = 40,
                      step = 20, keep_fits = TRUE)
  expect_no_error(capture.output(rm <- matrices(roll)))
  expect_equal(rm$beta, roll$fits[[1]]$beta)

  roll_no_fits <- fit_rolling_var(d, vars = c("A", "B", "C"), id = "id",
                              day = "day", beep = "beep", window_size = 40,
                              step = 20, keep_fits = FALSE)
  expect_error(matrices(roll_no_fits), "keep_fits")

  st <- estimate_stability(d, vars = c("A", "B", "C"), id = "id",
                           day = "day", beep = "beep", estimator = "var",
                           n_resamples = 2, seed = 1)
  expect_no_error(capture.output(sm <- matrices(st)))
  expect_equal(sm$beta, st$original$beta)

  cmp <- compare_idiographic(
    d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
    estimators = "var", keep_fits = TRUE
  )
  expect_no_error(capture.output(cm <- matrices(cmp, fit = "var")))
  expect_equal(cm$beta, cmp$fits$var$beta)
})

test_that("as_netobject.net_gimme defaults to proportion-weighted p-node group", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 4, days = 3, beeps = 12, vars = c("A", "B"), seed = 6)
  gm <- fit_gimme(d, vars = c("A", "B"), id = "id",
                    day = "day", beep = "beep", seed = 1)
  pn <- as_netobject(gm)                                  # default style/weight
  expect_s3_class(pn, "netobject_group")
  expect_named(pn, c("temporal", "contemporaneous"))
  expect_equal(pn$temporal$n_nodes, 2L)                  # p nodes, not 2p
  expect_true(pn$temporal$directed)
  expect_identical(pn$temporal$method, "relative")
  # Default weight is the proportion of subjects: t(path_counts[, lag] / n).
  expect_equal(pn$temporal$weights,
               t(gm$path_counts[, c("Alag", "Blag")] / gm$n_subjects),
               ignore_attr = TRUE)
  # All proportions are in [0, 1].
  expect_true(all(pn$temporal$weights >= 0 & pn$temporal$weights <= 1))
  expect_error(as_netobject(gm, style = "nope"))
})

test_that("as_netobject.net_gimme style='unified' is a 2p net; weight='coef' opt", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 4, days = 3, beeps = 12, vars = c("A", "B"), seed = 6)
  gm <- fit_gimme(d, vars = c("A", "B"), id = "id",
                    day = "day", beep = "beep", seed = 1)
  uni <- as_netobject(gm, style = "unified")
  expect_s3_class(uni, "cograph_network")
  expect_s3_class(uni, "netobject")
  expect_equal(uni$n_nodes, 4L)                          # 2p nodes
  # weight='coef' recovers the group-average coefficients.
  pn_coef <- as_netobject(gm, style = "pnode", weight = "coef")
  expect_equal(pn_coef$temporal$weights, t(gm$temporal_avg), ignore_attr = TRUE)
})

test_that("fit_gimme returns a mixed cograph_network from construction", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 4, days = 3, beeps = 12, vars = c("A", "B"), seed = 6)
  gm <- fit_gimme(d, vars = c("A", "B"), id = "id",
                    day = "day", beep = "beep", seed = 1)

  expect_s3_class(gm, "cograph_network")
  expect_identical(gm$meta$type, "mixed")
  expect_named(gm$nodes, c("id", "label", "name", "x", "y"))
  expect_true(all(c("from", "to", "weight", "type", "kind", "style",
                    "color", "level", "path", "from_label", "to_label",
                    "show_arrows") %in% names(gm$edges)))
  expect_type(gm$edges$from, "integer")
  expect_type(gm$edges$to, "integer")
  expect_true(any(gm$edges$kind == "lagged"))
  expect_true(all(gm$edges$style[gm$edges$kind == "lagged"] == "dashed"))
  expect_true(all(gm$edges$type %in% c("directed", "undirected")))

  group <- as_netobject(gm)
  expect_s3_class(group, "netobject_group")
  expect_named(group, c("temporal", "contemporaneous"))
})

test_that(".gimme_mixed_edges encodes gimme semantics; plot_gimme renders", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 6, days = 4, beeps = 12, vars = c("A", "B", "C"),
                   seed = 9)
  gm <- fit_gimme(d, vars = c("A", "B", "C"), id = "id",
                    day = "day", beep = "beep", seed = 1)
  edf <- idiographic:::.gimme_mixed_edges(gm)
  expect_named(edf, c("from", "to", "weight", "style", "color",
                      "kind", "path", "level"))
  # Autoregressive / fixed paths are group-level (black), matching gimme.
  ar_edges <- edf[edf$from == edf$to & edf$kind == "lagged", , drop = FALSE]
  expect_true(all(ar_edges$level == "group"))
  expect_true(all(ar_edges$color == "black"))
  # lagged -> dashed, contemp -> solid
  expect_true(all(edf$style[edf$kind == "lagged"]  == "dashed"))
  expect_true(all(edf$style[edf$kind == "contemp"] == "solid"))
  # weight is a proportion in (0, 1]
  expect_true(all(edf$weight > 0 & edf$weight <= 1))
  # group paths coloured black, others grey
  expect_true(all(edf$color[edf$path %in% gm$group_paths] == "black"))
  # autoregression appears as a dashed self-loop (from == to, lagged)
  ar <- edf[edf$from == edf$to, , drop = FALSE]
  expect_true(nrow(ar) >= 1 && all(ar$style == "dashed"))

  skip_if_not_installed("cograph")
  tmp <- tempfile(fileext = ".png"); grDevices::png(tmp)
  net <- plot_gimme(gm)
  expect_no_error(cograph::splot(gm, edge_style = gm$edges$style,
                                 edge_color = gm$edges$color,
                                 show_arrows = gm$edges$show_arrows))
  grDevices::dev.off()
  expect_s3_class(net, "cograph_network")
  expect_error(plot_gimme(1L), "net_gimme")
})

test_that("extract_edges works on a single net and rejects groups", {
  skip_on_cran()
  d <- synth_single(n_t = 100)
  gv <- fit_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                      day = "day", beep = "beep", n_lambda = 8, gamma = 0)
  no <- as_netobject(gv)
  ed <- extract_edges(no$contemporaneous)
  expect_s3_class(ed, "data.frame")
  expect_named(ed, c("from", "to", "weight"))
  # passing the whole result (a group) is a clear error, not a subscript crash
  expect_error(extract_edges(gv), "single network")
  expect_error(extract_edges(no), "single network")
})
