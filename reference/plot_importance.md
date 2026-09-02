# Plot feature importance

Plot feature importance

## Usage

``` r
plot_importance(
  x,
  model = NULL,
  scope = NULL,
  subject = NULL,
  n = 15,
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

  Number of rows/variables to plot.

- method:

  Importance method. `"coefficient"` uses absolute fitted coefficients
  where available; `"permutation"` measures the increase in held-out
  prediction error after shuffling a predictor.

- repeats:

  Number of shuffles per predictor for permutation importance.

- ...:

  Passed to base plotting functions.

## Value

Invisibly, the plotted importance table.
