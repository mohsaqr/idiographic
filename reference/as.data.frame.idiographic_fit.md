# Convert a consolidated fit to its prediction table

Convert a consolidated fit to its prediction table

## Usage

``` r
# S3 method for class 'idiographic_fit'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)

# S3 method for class 'idiostats_fit'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
```

## Arguments

- x:

  A consolidated `idiographic_fit`.

- row.names:

  Ignored.

- optional:

  Ignored.

- ...:

  Filters passed to
  [`predictions()`](https://pak.dynasite.org/idiographic/reference/predictions.md).

## Value

The `data.frame` of
[`predictions()`](https://pak.dynasite.org/idiographic/reference/predictions.md):
one row per held-out occasion and model.

## Examples

``` r
fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
head(as.data.frame(fit, scope = "pooled"))
#>    scope model estimator subject subgroup row observed predicted  residual
#> 1 pooled    lm    native   Aisha     .all 125 58.73016  64.07019 -5.340027
#> 2 pooled    lm    native   Aisha     .all 126 90.47619  69.80912 20.667074
#> 3 pooled    lm    native   Aisha     .all 127 87.30159  66.93965 20.361936
#> 4 pooled    lm    native   Aisha     .all 128 87.30159  52.59233 34.709261
#> 5 pooled    lm    native   Aisha     .all 129 71.42857  68.37438  3.054188
#> 6 pooled    lm    native   Aisha     .all 130 80.95238  51.15759 29.794787
```
