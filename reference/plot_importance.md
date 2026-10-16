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
  type = c("overall", "person", "boxplot", "density", "frequency", "comparison"),
  ...
)
```

## Arguments

- x:

  An idiographic fit or a table returned by
  [`importance()`](https://pak.dynasite.org/idiographic/reference/importance.md).

- model, scope, subject:

  Optional filters.

- n:

  Maximum rows in the overall plot or predictors per person. For
  frequency plots, the top-feature rank threshold (ties retained).
  Distribution and comparison plots retain all available predictors.

- method:

  Importance method. `"coefficient"` uses absolute fitted coefficients
  where available; `"permutation"` measures the increase in held-out
  prediction error after shuffling a predictor.

- repeats:

  Number of shuffles per predictor for permutation importance.

- type:

  Overall points (default), per-person profiles (`"person"`), learner
  distributions (`"boxplot"`, `"density"`), top-feature frequencies
  (`"frequency"`), or pooled/individual means (`"comparison"`).

- ...:

  Passed to base plotting functions.

## Value

Invisibly, the plotted importance table.
