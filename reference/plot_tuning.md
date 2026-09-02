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

Invisibly, the tuning table.
