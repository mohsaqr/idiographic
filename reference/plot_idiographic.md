# Plot an idiographic network result

S3 [`plot()`](https://rdrr.io/r/graphics/plot.default.html) methods that
render any idiographic result with
[`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html).
Call `plot(fit)` to draw the full result (every network panel) or pass
`layer` to draw a single network – `"temporal"`, `"contemporaneous"`,
`"between"` (mlVAR), or `"residual_cov"` (uSEM) – without indexing into
the object.

## Usage

``` r
# S3 method for class 'var_result'
plot(x, layer = NULL, mixed = FALSE, ...)

# S3 method for class 'gvar_result'
plot(x, layer = NULL, mixed = FALSE, ...)

# S3 method for class 'var_bayes_result'
plot(x, layer = NULL, mixed = FALSE, ...)

# S3 method for class 'net_mlvar'
plot(x, layer = NULL, mixed = FALSE, ...)

# S3 method for class 'net_usem'
plot(x, layer = NULL, mixed = FALSE, ...)

# S3 method for class 'net_gimme'
plot(x, layer = NULL, weight = c("prop", "coef"), ...)

# S3 method for class 'var_list'
plot(x, subject = 1L, layer = NULL, ...)

# S3 method for class 'gvar_list'
plot(x, subject = 1L, layer = NULL, ...)

# S3 method for class 'rolling_var_result'
plot(x, fit = 1L, layer = NULL, ...)

# S3 method for class 'rolling_gvar_result'
plot(x, fit = 1L, layer = NULL, ...)

# S3 method for class 'stability_result'
plot(x, layer = NULL, ...)
```

## Arguments

- x:

  An idiographic result (`var_result`, `gvar_result`, `net_mlvar`,
  `net_usem`, `net_gimme`, `var_list`, `rolling_var_result`,
  `rolling_gvar_result`, or `stability_result`).

- layer:

  Optional network name to draw on its own. `NULL` (default) draws the
  whole result. Available names are reported if an unknown one is given.

- mixed:

  If `TRUE`, draw two layers as a single mixed network via
  [`cograph::plot_mixed_network()`](https://sonsoles.me/cograph/reference/plot_mixed_network.html)
  — the directed layer as curved arrows and the undirected layer as
  straight edges. For VAR, graphical VAR, and multilevel VAR this
  combines the directed temporal network with the undirected
  contemporaneous network; for uSEM it combines the directed
  contemporaneous paths with the undirected residual covariances.
  Default `FALSE` draws one panel per layer.

- ...:

  Further arguments forwarded to
  [`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html).

- weight:

  For GIMME: `"prop"` (proportion of subjects, default) or `"coef"`
  (group-average coefficient) for edge width.

- subject:

  For a `var_list` / `gvar_list`: the subject name (or index) to draw.
  Defaults to the first subject.

- fit:

  For rolling results: the stored window fit (name or index) to draw.
  Requires `keep_fits = TRUE` at fit time. Defaults to the first window.

## Value

Invisibly, the object that was plotted (a `cograph`/ggplot object).

## Examples

``` r
set.seed(1)
d <- data.frame(id = 1, A = rnorm(80), B = rnorm(80), C = rnorm(80))
fit <- fit_var(d, vars = c("A", "B", "C"), id = "id")
plot(fit)

plot(fit, layer = "temporal")
```
