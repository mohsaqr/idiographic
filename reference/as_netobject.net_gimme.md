# Plottable netobject(s) from a GIMME fit

Returns the GIMME result as matrix-backed netobjects. By default these
encode the **same quantity the `gimme` package plots** — the *proportion
of subjects* that have each path (`path_counts / n_subjects`) — not the
group-average coefficient (which dilutes toward zero and is not what
GIMME displays). For the faithful single mixed network (dashed lag /
solid contemporaneous, group/individual colouring, autoregressive
self-loops) use
[`plot_gimme()`](https://mohsaqr.github.io/idiographic/reference/plot_gimme.md).

## Usage

``` r
# S3 method for class 'net_gimme'
as_netobject(x, style = c("pnode", "unified"), weight = c("prop", "coef"), ...)
```

## Arguments

- x:

  A `net_gimme` object.

- style:

  Either `"pnode"` (default) — a `netobject_group` of two directed
  `p`-node networks, `$temporal` (lagged; autoregression on the
  diagonal) and `$contemporaneous` (same-beep), matching the shape
  [`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md)
  returns — or `"unified"`, a single directed `2p`-node network with the
  `*_lag` half feeding the current half (the literal uSEM topology).

- weight:

  Either `"prop"` (default) — edge weight is the proportion of subjects
  with the path — or `"coef"`, the group-average standardized
  coefficient.

- ...:

  Unused.

## Value

For `style = "pnode"`, a `netobject_group` with `$temporal` and
`$contemporaneous`. For `style = "unified"`, one
`c("netobject", "cograph_network")` object with `2p` nodes.

## See also

[`plot_gimme()`](https://mohsaqr.github.io/idiographic/reference/plot_gimme.md)
for the faithful gimme-style mixed plot.
