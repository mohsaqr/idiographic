# Units that could not be fitted

Returns the failure table of a result: one row per unit (person, window,
model or resample) whose estimation failed or was skipped, with the
reason. Persons with too few complete training or held-out occasions,
for example, receive no person-specific model and are listed here
instead of being dropped silently.

## Usage

``` r
failures(x, model = NULL, scope = NULL, subject = NULL, ...)

# Default S3 method
failures(x, model = NULL, scope = NULL, subject = NULL, ...)
```

## Arguments

- x:

  A result that records failures, such as a fit from
  [`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md),
  [`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md),
  [`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md),
  [`fit_ml()`](https://pak.dynasite.org/idiographic/reference/fit_ml.md)
  or
  [`fit_effects()`](https://pak.dynasite.org/idiographic/reference/fit_effects.md),
  a subgroup result from
  [`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md),
  a rolling network result, or a model comparison.

- model, scope, subject:

  Optional filters, applied when the table has the matching column.

- ...:

  Ignored.

## Value

A base `data.frame` with one row per failed unit. For model fits the
columns are `scope`, `model`, `estimator`, `subject` and `message`;
other results keep the identifying columns of their own units and a
`message` column. A result without failures returns a table with zero
rows.

## Errors

Raises an error of class `idiographic_no_failure_table` when `x` keeps
no failure table.

## Examples

``` r
# Aisha keeps only 8 days, too few for a person-specific model.
short <- subset(srl, name != "Aisha" | day <= 8)
fit <- fit_lm(short, y = "effort", x = "efficacy", id = "name",
              time = "day", scope = "individual")
failures(fit)
#>   scope  model estimator subject
#> 1 split .split    .split   Aisha
#>                                                        message
#> 1 Insufficient complete rows (train = 6, valid = 0, test = 2).
```
