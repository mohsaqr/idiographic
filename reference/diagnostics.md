# Model diagnostics

Model diagnostics

## Usage

``` r
diagnostics(x, model = NULL, scope = NULL, subject = NULL, n = NULL, ...)
```

## Arguments

- x:

  An idiographic fit.

- model, scope, subject:

  Optional filters.

- n:

  Optional number of rows.

- ...:

  Ignored.

## Value

A `data.frame` with one row per held-out occasion and model: the columns
of
[`predictions()`](https://pak.dynasite.org/idiographic/reference/predictions.md)
plus, for regression, `abs_error`, `squared_error` and `std_residual`
(the residual divided by the residual standard deviation of its scope,
model and person), and, for classification, `correct` and `brier`.

## Examples

``` r
fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
diagnostics(fit, scope = "individual", subject = "Aisha", n = 5)
#>        scope model estimator subject subgroup row observed predicted   residual
#> 1 individual    lm    native   Aisha    .none 125 58.73016  79.71301 -20.982856
#> 2 individual    lm    native   Aisha    .none 126 90.47619  83.25482   7.221367
#> 3 individual    lm    native   Aisha    .none 127 87.30159  81.48392   5.817668
#> 4 individual    lm    native   Aisha    .none 128 87.30159  72.62940  14.672191
#> 5 individual    lm    native   Aisha    .none 129 71.42857  82.36937 -10.940800
#>   abs_error squared_error std_residual
#> 1 20.982856     440.28023   -1.5071634
#> 2  7.221367      52.14814    0.5186987
#> 3  5.817668      33.84527    0.4178734
#> 4 14.672191     215.27319    1.0538789
#> 5 10.940800     119.70110   -0.7858593
```
