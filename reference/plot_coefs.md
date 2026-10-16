# Plot person-specific coefficients and their heterogeneity

One row per person: the person-specific estimate of `term` with its 95%
confidence interval (estimate plus or minus 1.96 standard errors),
sorted by size. The vertical line marks the random-effects pooled
estimate from
[`pool_coefs()`](https://pak.dynasite.org/idiographic/reference/pool_coefs.md),
and the shaded band marks the range in which 95% of the true
person-specific coefficients are expected to fall (pooled estimate plus
or minus 1.96 `tau`). A wide band indicates that persons differ in the
coefficient beyond what sampling error explains.

## Usage

``` r
plot_coefs(x, term, ...)
```

## Arguments

- x:

  A fit from
  [`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md)
  or
  [`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md)
  that includes `scope = "individual"`.

- term:

  The coefficient to plot.

- ...:

  Ignored.

## Value

Invisibly, the plotted person-specific coefficients (one row per
person).

## Examples

``` r
fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day",
              scope = "individual")
plot_coefs(fit, term = "efficacy")
```
