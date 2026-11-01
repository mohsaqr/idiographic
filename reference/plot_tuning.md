# Plot tuning results

Plot tuning results

## Usage

``` r
plot_tuning(x, model = NULL, scope = NULL, subject = NULL, metric = NULL, ...)
```

## Arguments

- x:

  An idiographic fit.

- model, scope, subject:

  Optional filters.

- metric:

  Metric to plot. Defaults to `rmse` when present, otherwise `accuracy`.

- ...:

  Passed to base plotting functions.

## Value

Invisibly, the `data.frame` of
[`tuning()`](https://pak.dynasite.org/idiographic/reference/tuning.md)
that was plotted, one row per candidate setting.

## Examples

``` r
fit <- fit_ml(srl, y = "effort", x = "efficacy:monitoring", id = "name",
              time = "day", scope = "pooled", model = "knn", tune = TRUE)
plot_tuning(fit)
```
