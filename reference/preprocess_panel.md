# Prepare repeated-measures data for idiographic modelling

Three transforms that idiographic work almost always needs, in one call.

## Usage

``` r
preprocess_panel(
  data,
  id,
  time = NULL,
  vars = NULL,
  center = c("none", "person", "grand"),
  scale = c("none", "person", "grand"),
  lag = NULL,
  decompose = FALSE,
  lag_max_gap = NULL,
  detrend = c("none", "person", "grand"),
  detrend_alpha = 0.05
)
```

## Arguments

- data:

  Data frame.

- id:

  Person/unit ID column.

- time:

  Optional ordering column. Required for `lag`.

- vars:

  Columns to transform (any
  [`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md)
  selector). Defaults to every numeric column other than `id` and
  `time`.

- center:

  `"none"`, `"person"`, or `"grand"`.

- scale:

  `"none"`, `"person"`, or `"grand"`.

- lag:

  Integer lags to create, e.g. `lag = 1` or `lag = 1:2`.

- decompose:

  Append `<var>_within` and `<var>_between` columns.

- lag_max_gap:

  Largest elapsed time a lag may span, on the scale of `time`. A lagged
  value reaching further back becomes `NA`. `NULL` accepts any gap,
  which is only safe when occasions are evenly spaced.

- detrend:

  `"none"`, `"person"` (each person's own trend over their own
  occasions), or `"grand"` (one trend across everyone). Needs `time`.

- detrend_alpha:

  Only remove a trend when it is significant at this level. Set to `1`
  to detrend unconditionally.

## Value

The data frame, transformed in place, with any lag and decomposition
columns appended.

## Details

**Person-centering** (`center = "person"`) subtracts each person's own
mean, so what remains is how a person varies *around themselves*. This
is the transform that separates a within-person effect from a
between-person one: on raw scores a predictor can look strong only
because high-scoring people also score high on the outcome, while within
any single person it does nothing. Grand-centering (`center = "grand"`)
subtracts one overall mean and does not remove that confound.

**Person-scaling** (`scale = "person"`) divides by each person's own
standard deviation, putting people on a common footing when they differ
in how much they fluctuate.

**Lagging** (`lag`) adds `<var>_lag1`-style columns, shifted *within*
each person and in time order, so a person's yesterday never leaks into
another person's today. Rows with no predecessor get `NA`; the fitters
drop them.

A lag counts **occasions, not elapsed time**. When sampling is irregular
that is a real hazard: "the previous occasion" may be twenty minutes
back for one row and three days back for the next, and a lag-1 effect
estimated across both is not one quantity. Give `lag_max_gap` to refuse
the stretched ones – a lagged value whose actual gap exceeds it becomes
`NA` rather than a silently incomparable number.
[`describe_persons()`](https://pak.dynasite.org/idiographic/reference/describe_persons.md)
reports `gap_median` and `gap_max` so you can see whether this applies
to your data before choosing.

**Detrending** (`detrend`) removes a linear time trend, so that what
remains is fluctuation around a person's trajectory rather than the
trajectory itself. Two people can both be rising steadily and appear
strongly correlated on every variable purely because time is passing.
Following the usual experience-sampling convention the trend is removed
**only when it is significant** (`detrend_alpha = 0.05`); set
`detrend_alpha = 1` to remove it unconditionally. `detrend = "person"`
fits each person's own trend over their own occasions – the idiographic
choice, and the default meaning of detrending here – while `"grand"`
fits a single trend across everyone.

Detrending preserves each series' **level**: the residuals have the mean
added back, so `detrend` removes only the slope and stays independent of
`center`. Series with fewer than three usable occasions are left alone.

**Decomposing** (`decompose = TRUE`) keeps *both* halves instead of
choosing one: it appends `<var>_within` (the deviation from the person's
own mean) and `<var>_between` (that mean), leaving the original column
untouched. This is the input a within-between model needs – see
[`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md),
which does the same split internally on training rows only.
Person-centering and decomposition are alternatives, not companions:
centering throws the between half away, so asking for both at once is
refused.

## Examples

``` r
# Within-person variation only, plus yesterday's efficacy.
prepped <- preprocess_panel(srl, id = "name", time = "day",
                      vars = "efficacy:monitoring",
                      center = "person", lag = 1)
fit_lm(prepped, y = "effort", x = c("efficacy", "efficacy_lag1"),
       id = "name", time = "day")
#> Idiographic Fit
#>   Method:      lm
#>   Outcome:     effort (regression)
#>   Predictors:  2 (efficacy, efficacy_lag1)
#>   ID:          name
#>   Scope:       pooled + individual
#>   Models:      lm [native]
#>   Subjects:    36
#>   Predictions: 2300
#>   Best RMSE:   19.3110 (individual/lm)
#>   Use metrics(), predictions(), coefs(), compare()

# Keep both halves, so the two effects can be compared in one model. A
# between-person column is constant inside a person, so it only belongs in a
# pooled model -- or use fit_within_between(), which handles the split itself.
split <- preprocess_panel(srl, id = "name", vars = c("efficacy", "planning"),
                    decompose = TRUE)
fit_lm(split, y = "effort", x = c("efficacy_within", "efficacy_between"),
       id = "name", scope = "pooled")
#> Idiographic Fit
#>   Method:      lm
#>   Outcome:     effort (regression)
#>   Predictors:  2 (efficacy_within, efficacy_between)
#>   ID:          name
#>   Scope:       pooled
#>   Models:      lm [native]
#>   Subjects:    36
#>   Predictions: 1150
#>   Best RMSE:   21.9757 (pooled/lm)
#>   Use metrics(), predictions(), coefs(), compare()
```
