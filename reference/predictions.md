# Tidy held-out predictions

Tidy held-out predictions

## Usage

``` r
predictions(
  x,
  model = NULL,
  scope = NULL,
  subject = NULL,
  n = NULL,
  overall = FALSE,
  sort_by = NULL,
  decreasing = FALSE,
  ...
)
```

## Arguments

- x:

  An idiographic fit.

- model, scope, subject:

  Optional filters.

- n:

  Optional number of rows to return.

- overall:

  Logical. If `TRUE`, return only overall rows when present.

- sort_by:

  Optional column to sort by.

- decreasing:

  Sort order when `sort_by` is supplied.

- ...:

  Ignored.

## Value

A `data.frame` with one row per held-out occasion and model: `scope`,
`model`, `estimator`, `subject`, `subgroup`, `row` (row of the input
data), `observed`, `predicted` and, for regression, `residual`.
Classification fits also report the predicted `probability`.

## Examples

``` r
fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
predictions(fit, scope = "individual", subject = "Aisha", n = 5)
#>        scope model estimator subject subgroup row observed predicted   residual
#> 1 individual    lm    native   Aisha    .none 125 58.73016  79.71301 -20.982856
#> 2 individual    lm    native   Aisha    .none 126 90.47619  83.25482   7.221367
#> 3 individual    lm    native   Aisha    .none 127 87.30159  81.48392   5.817668
#> 4 individual    lm    native   Aisha    .none 128 87.30159  72.62940  14.672191
#> 5 individual    lm    native   Aisha    .none 129 71.42857  82.36937 -10.940800
```
