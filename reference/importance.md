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

A tidy data frame.
