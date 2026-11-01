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

Invisibly, the `data.frame` of
[`diagnostics()`](https://pak.dynasite.org/idiographic/reference/diagnostics.md)
that was plotted, one row per held-out occasion and model.

## Examples

``` r
fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
plot_diagnostics(fit, scope = "individual")

plot_diagnostics(fit, scope = "individual", type = "calibration")
```
