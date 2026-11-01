# Feature importance

Returns a tidy feature-importance table. For coefficient-based native
models, importance is the absolute coefficient magnitude after the
model's internal scaling. For simple tree models, the selected split
variable receives the split contrast magnitude.

## Usage

``` r
importance(
  x,
  model = NULL,
  scope = NULL,
  subject = NULL,
  n = NULL,
  method = c("coefficient", "permutation"),
  repeats = 5L,
  ...
)
```

## Arguments

- x:

  An idiographic fit.

- model, scope, subject:

  Optional filters.

- n:

  Optional number of rows.

- method, repeats:

  Only for `importance()`. `"coefficient"` (the default) uses the size
  of each standardized coefficient, which only describes models that
  have coefficients. `"permutation"` shuffles each predictor in the
  held-out rows and reports how much worse the model gets –
  model-agnostic, so it also explains `knn`, forests, kernel machines
  and boosted ensembles, which otherwise return nothing at all;
  `repeats` is the number of shuffles.

- ...:

  Ignored.

## Value

A `data.frame` with one row per scope, model, estimator, person and
predictor: `scope`, `model`, `estimator`, `subject`, `subgroup`,
`variable` and `importance`, largest first. Models without coefficients
return no rows under `method = "coefficient"`.

## Examples

``` r
fit <- fit_lm(srl, y = "effort", x = "efficacy:monitoring", id = "name",
              time = "day")
importance(fit, scope = "pooled")
#>    scope model estimator subject subgroup   variable importance
#> 1 pooled    lm    native    .all     .all   planning  0.2685459
#> 2 pooled    lm    native    .all     .all   efficacy  0.2207958
#> 3 pooled    lm    native    .all     .all      value  0.1816368
#> 4 pooled    lm    native    .all     .all monitoring  0.1159570

# Which predictor matters most for each of three learners?
importance(fit, scope = "individual", subject = c("Aisha", "Alice", "Bob"))
#>         scope model estimator subject subgroup   variable  importance
#> 1  individual    lm    native     Bob    .none monitoring 0.488182027
#> 2  individual    lm    native     Bob    .none      value 0.448829571
#> 3  individual    lm    native     Bob    .none   efficacy 0.403378493
#> 4  individual    lm    native   Alice    .none   planning 0.298873611
#> 5  individual    lm    native   Alice    .none   efficacy 0.276829333
#> 6  individual    lm    native   Aisha    .none      value 0.225149907
#> 7  individual    lm    native   Alice    .none      value 0.178358367
#> 8  individual    lm    native   Alice    .none monitoring 0.147803809
#> 9  individual    lm    native   Aisha    .none   planning 0.143545323
#> 10 individual    lm    native   Aisha    .none monitoring 0.119170981
#> 11 individual    lm    native   Aisha    .none   efficacy 0.012814875
#> 12 individual    lm    native     Bob    .none   planning 0.004203027
```
