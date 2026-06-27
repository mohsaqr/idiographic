test_that("as_netobject.gvar_result preserves plotting method names", {
  d <- synth_single(n_t = 100)
  gv <- graphical_var(d, vars = c("A", "B", "C"), id = "id",
                      day = "day", beep = "beep", n_lambda = 8, gamma = 0.5)
  no <- as_netobject(gv)
  expect_s3_class(no, "netobject_group")
  expect_identical(no$temporal$method, "relative")
  expect_identical(no$contemporaneous$method, "co_occurrence")
  expect_true(no$temporal$directed)
  expect_false(no$contemporaneous$directed)
})

test_that("as_netobject.cograph_network recovers a nested method", {
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

test_that("as_netobject.net_gimme defaults to proportion-weighted p-node group", {
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 4, days = 3, beeps = 12, vars = c("A", "B"), seed = 6)
  gm <- build_gimme(d, vars = c("A", "B"), id = "id",
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
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 4, days = 3, beeps = 12, vars = c("A", "B"), seed = 6)
  gm <- build_gimme(d, vars = c("A", "B"), id = "id",
                    day = "day", beep = "beep", seed = 1)
  uni <- as_netobject(gm, style = "unified")
  expect_s3_class(uni, "netobject")
  expect_equal(uni$n_nodes, 4L)                          # 2p nodes
  # weight='coef' recovers the group-average coefficients.
  pn_coef <- as_netobject(gm, style = "pnode", weight = "coef")
  expect_equal(pn_coef$temporal$weights, t(gm$temporal_avg), ignore_attr = TRUE)
})

test_that(".gimme_mixed_edges encodes gimme semantics; plot_gimme renders", {
  skip_if_not_installed("lavaan")
  d <- synth_panel(n_id = 6, days = 4, beeps = 12, vars = c("A", "B", "C"),
                   seed = 9)
  gm <- build_gimme(d, vars = c("A", "B", "C"), id = "id",
                    day = "day", beep = "beep", seed = 1)
  edf <- idionet:::.gimme_mixed_edges(gm)
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
  grDevices::dev.off()
  expect_true(inherits(net, "cograph_network") || is.list(net))
  expect_error(plot_gimme(1L), "net_gimme")
})

test_that("extract_edges works on a single net and rejects groups", {
  d <- synth_single(n_t = 100)
  gv <- graphical_var(d, vars = c("A", "B", "C"), id = "id",
                      day = "day", beep = "beep", n_lambda = 8, gamma = 0)
  no <- as_netobject(gv)
  ed <- extract_edges(no$contemporaneous)
  expect_s3_class(ed, "data.frame")
  expect_named(ed, c("from", "to", "weight"))
  # passing the whole result (a group) is a clear error, not a subscript crash
  expect_error(extract_edges(gv), "single network")
  expect_error(extract_edges(no), "single network")
})
