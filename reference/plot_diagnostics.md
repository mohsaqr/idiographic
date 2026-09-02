# Plot model diagnostics

Plot model diagnostics

## Usage

``` r
plot_diagnostics(
  x,
  model = NULL,
  scope = NULL,
  subject = NULL,
  type = c("residuals", "observed", "calibration"),
  ...
)
```

## Arguments

- x:

  An idiographic fit.

- model, scope, subject:

  Optional filters.

- type:

  Diagnostic plot type: `"residuals"`, `"observed"`, or `"calibration"`.

- ...:

  Passed to base plotting functions.

## Value

Invisibly, the diagnostic table.
