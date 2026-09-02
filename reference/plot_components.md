# Plot within-person against between-person effects

One row per predictor, with the within and between coefficients and
their confidence intervals. A predictor whose two intervals do not
overlap is one where pooling the two processes into a single coefficient
would mislead.

## Usage

``` r
plot_components(x, scope = "pooled", subject = NULL, subgroup = NULL, ...)
```

## Arguments

- x:

  A
  [`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md)
  result.

- scope, subject, subgroup:

  Optional filters.

- ...:

  Passed to base plotting functions.

## Value

Invisibly, the plotted table.

## Examples

``` r
fit <- fit_within_between(srl, y = "effort", x = c("efficacy", "planning"),
                          id = "name", time = "day")
plot_components(fit)
```
