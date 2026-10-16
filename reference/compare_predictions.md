# Compare prediction errors on paired observations

Compares each person's model with its pooled counterpart or with a mean
baseline at the same scope. Only pairs evaluated on identical
observations are compared. Positive gain indicates improvement over the
reference.

## Usage

``` r
compare_predictions(
  x,
  reference = c("pooled", "mean"),
  metric = "rmse",
  model = NULL,
  scope = "individual",
  subject = NULL
)
```

## Arguments

- x:

  An idiographic fit.

- reference:

  `"pooled"` or `"mean"`.

- metric:

  A metric column, such as `"rmse"` or `"accuracy"`.

- model, scope, subject:

  Optional filters for the models being compared.

## Value

A data frame with one row per paired person/model comparison, including
`value`, `reference_value`, and `gain`.

## Examples

``` r
fit <- fit_ml(srl, y = "effort", x = "efficacy", id = "name",
              time = "day", scope = "both", model = c("mean", "ridge"))
compare_predictions(fit, reference = "pooled", model = "ridge")
#>    subject      scope subgroup model estimator  n metric    value reference
#> 1    Aisha individual    .none ridge    native 32   rmse 13.76959    pooled
#> 2    Alice individual    .none ridge    native 32   rmse 18.87258    pooled
#> 3    Anika individual    .none ridge    native 32   rmse 20.33867    pooled
#> 4   Astrid individual    .none ridge    native 32   rmse 17.15679    pooled
#> 5    Bjorn individual    .none ridge    native 32   rmse 12.04664    pooled
#> 6      Bob individual    .none ridge    native 32   rmse 16.64900    pooled
#> 7  Charlie individual    .none ridge    native 32   rmse 20.74873    pooled
#> 8    Diana individual    .none ridge    native 32   rmse 10.46647    pooled
#> 9     Erik individual    .none ridge    native 32   rmse 29.75909    pooled
#> 10     Eve individual    .none ridge    native 32   rmse 27.70886    pooled
#> 11  Fatima individual    .none ridge    native 32   rmse 20.57354    pooled
#> 12   Frank individual    .none ridge    native 32   rmse 28.54102    pooled
#> 13   Freja individual    .none ridge    native 32   rmse 17.69713    pooled
#> 14   Grace individual    .none ridge    native 32   rmse 20.58860    pooled
#> 15  Hassan individual    .none ridge    native 32   rmse 16.74261    pooled
#> 16   Heidi individual    .none ridge    native 32   rmse 23.47693    pooled
#> 17 Hiroshi individual    .none ridge    native 32   rmse 12.06085    pooled
#> 18  Ingrid individual    .none ridge    native 32   rmse 17.76331    pooled
#> 19    Ivan individual    .none ridge    native 32   rmse 16.67150    pooled
#> 20    Judy individual    .none ridge    native 32   rmse 14.52560    pooled
#> 21   Karin individual    .none ridge    native 32   rmse 19.41983    pooled
#> 22    Lars individual    .none ridge    native 32   rmse 15.00438    pooled
#> 23   Layla individual    .none ridge    native 30   rmse 24.48856    pooled
#> 24      Li individual    .none ridge    native 32   rmse 14.33093    pooled
#> 25     Liv individual    .none ridge    native 32   rmse 12.47193    pooled
#> 26     Mei individual    .none ridge    native 32   rmse 22.60098    pooled
#> 27    Nils individual    .none ridge    native 32   rmse 17.99916    pooled
#> 28    Noor individual    .none ridge    native 32   rmse 13.62383    pooled
#> 29    Omar individual    .none ridge    native 32   rmse 18.79402    pooled
#> 30    Ravi individual    .none ridge    native 32   rmse 16.25694    pooled
#> 31  Saanvi individual    .none ridge    native 32   rmse 16.24314    pooled
#> 32  Sakura individual    .none ridge    native 32   rmse 21.19341    pooled
#> 33    Sven individual    .none ridge    native 32   rmse 23.39273    pooled
#> 34  Takumi individual    .none ridge    native 32   rmse 16.13956    pooled
#> 35    Yuki individual    .none ridge    native 32   rmse 24.57320    pooled
#> 36    Zain individual    .none ridge    native 32   rmse 19.27206    pooled
#>    reference_value       gain
#> 1         23.30745  9.5378569
#> 2         20.36721  1.4946359
#> 3         22.24599  1.9073180
#> 4         17.73888  0.5820939
#> 5         12.72625  0.6796092
#> 6         17.39927  0.7502739
#> 7         21.92145  1.1727166
#> 8         15.81492  5.3484484
#> 9         30.72682  0.9677273
#> 10        28.99484  1.2859735
#> 11        23.99015  3.4166084
#> 12        33.41993  4.8789060
#> 13        23.66011  5.9629791
#> 14        23.29287  2.7042715
#> 15        15.84368 -0.8989280
#> 16        23.74367  0.2667346
#> 17        23.98312 11.9222695
#> 18        29.81621 12.0528959
#> 19        19.69077  3.0192721
#> 20        17.03643  2.5108359
#> 21        21.36711  1.9472834
#> 22        22.88360  7.8792223
#> 23        25.90254  1.4139803
#> 24        20.62558  6.2946512
#> 25        18.00762  5.5356934
#> 26        22.72946  0.1284850
#> 27        17.50607 -0.4930902
#> 28        17.85430  4.2304742
#> 29        25.42550  6.6314828
#> 30        22.32031  6.0633740
#> 31        17.00278  0.7596338
#> 32        20.76230 -0.4311093
#> 33        23.65394  0.2612171
#> 34        16.59684  0.4572805
#> 35        24.38774 -0.1854665
#> 36        18.44236 -0.8296974
```
