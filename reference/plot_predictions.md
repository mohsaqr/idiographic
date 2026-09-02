# Plot held-out prediction trajectories

One panel per person: what actually happened, and what the model said
would happen, over the held-out occasions. This is the plot that shows
whether a model tracks a person, which a scatter of everyone pooled
together hides.

## Usage

``` r
plot_predictions(
  x,
  model = NULL,
  scope = NULL,
  subject = NULL,
  n_subjects = 4L,
  ...
)
```

## Arguments

- x:

  An idiographic fit.

- model, scope, subject:

  Optional filters.

- n_subjects:

  Maximum number of people to draw.

- ...:

  Passed to base plotting functions.

## Value

Invisibly, the plotted table.

## Examples

``` r
fit <- fit_ml(srl, y = "effort", x = "efficacy:monitoring", id = "name",
              time = "day", model = "ridge", scope = "individual")
plot_predictions(fit, n_subjects = 4)
```
