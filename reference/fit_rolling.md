# Rolling-origin validation for ordered repeated measures

Instead of one hold-out block per person, the origin walks forward:
train on each person's first `initial` rows and predict the next
`assess`, then move the origin on by `step` and repeat. Every fold
trains only on the past, so the result is a forecast, not a fit.

## Usage

``` r
fit_rolling(
  data,
  y,
  x,
  id,
  method = c("lm", "glm", "ml"),
  time = NULL,
  scope = "both",
  subgroup = NULL,
  initial = NULL,
  assess = 1L,
  step = NULL,
  folds = 5L,
  min_train = 10L,
  tune = FALSE,
  valid_prop = 0.2,
  ...
)
```

## Arguments

- data:

  Data frame.

- y:

  Outcome column name.

- x:

  Predictors: names, numeric positions, `a:b` range, formula, or data
  frame.

- id:

  Person/unit ID column.

- method:

  Which family to fit each fold with: `"lm"`, `"glm"`, or `"ml"`.

- time:

  Optional ordering column.

- scope:

  `"both"` (pooled + individual), `"pooled"`, `"individual"`,
  `"subgroup"`, or `"all"` (pooled + subgroup + individual).

- subgroup:

  Optional subgroup mapping: an
  [`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md)
  result, a grouping column in `data`, or a named vector of labels per
  person.

- initial:

  Rows each person trains on in the first fold. Defaults to whatever
  leaves room for `folds` folds.

- assess:

  Rows predicted per fold.

- step:

  How far the origin moves between folds. Defaults to `assess`
  (contiguous, non-overlapping test blocks).

- folds:

  Number of folds.

- min_train:

  Minimum complete training rows per person.

- tune:

  Logical. Tune each fold on a validation block carved from that fold's
  training rows, so no fold's test rows influence its own settings.

- valid_prop:

  Proportion of each fold's training rows used for tuning.

- ...:

  Passed to the underlying fitter, e.g. `model` or `family`.

## Value

An `idiographic_fit` whose `predictions` carry a `fold` column.

## Details

Predictions gain a `fold` column. Metrics pool across folds, so
[`metrics()`](https://pak.dynasite.org/idiographic/reference/metrics.md)
answers "how well does this model forecast this person over time" rather
than "how well did it do on one arbitrary split".

## Examples

``` r
fit <- fit_rolling(srl, y = "effort", x = "efficacy:monitoring", id = "name",
                   time = "day", method = "ml", model = "ridge", folds = 3)
metrics(fit, overall = TRUE)
#>        scope model estimator  subject subgroup   n     rmse      mae     bias
#> 1     pooled ridge    native .overall     .all 108 20.18199 15.97641 1.847201
#> 2 individual ridge    native .overall     .all 108 18.40502 13.93209 2.781897
#>   r_squared
#> 1 0.4599228
#> 2 0.5508409
```
