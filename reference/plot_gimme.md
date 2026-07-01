# Faithful GIMME network plot (the `gimme`-package convention, via cograph)

Draws a GIMME result the way the `gimme` package does: a single `p`-node
network where **dashed edges are lag-1 (temporal)** and **solid edges
are lag-0 (contemporaneous)**, **edge width is the proportion of
subjects** that have the path, **black edges are group-level** paths and
grey edges individual-level, and autoregression shows as a dashed
self-loop. Rendered with
[`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html),
so a lag and a contemporaneous effect between the same pair are drawn as
two parallel edges.

## Usage

``` r
plot_gimme(
  x,
  weight = c("prop", "coef"),
  group_color = "black",
  individual_color = "grey60",
  layout = "circle",
  curvature = 0.25,
  edge_scale = 5,
  ...
)
```

## Arguments

- x:

  A `net_gimme` object from
  [`build_gimme()`](https://mohsaqr.github.io/idiographic/reference/build_gimme.md).

- weight:

  `"prop"` (default, proportion of subjects) or `"coef"` (group-average
  standardized coefficient) for edge width.

- group_color, individual_color:

  Edge colours for group- vs individual-level paths. Defaults `"black"`
  / `"grey60"`.

- layout:

  cograph layout passed to
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html).
  Default `"circle"`, matching gimme.

- curvature:

  Edge curvature (separates parallel lag/contemp edges). Default `0.25`.

- edge_scale:

  Multiplier mapping weight to drawn line width. Default `5`.

- ...:

  Further arguments forwarded to
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html).

## Value

Invisibly, the mixed `cograph_network` object that was plotted.

## See also

[`as_netobject()`](https://mohsaqr.github.io/idiographic/reference/as_netobject.md)
for the matrix view.

## Examples

``` r
# \donttest{
set.seed(1)
panel <- data.frame(
  id = rep(1:5, each = 30),
  t  = rep(seq_len(30), 5),
  A  = rnorm(150), B = rnorm(150), C = rnorm(150)
)
gm <- build_gimme(panel, vars = c("A", "B", "C"), id = "id", time = "t")
plot_gimme(gm)

# }
```
