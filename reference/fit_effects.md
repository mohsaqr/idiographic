# Estimate treatment effects and their heterogeneity

Answers a different question from the other fitters: not "how well can
we predict this person" but "how much did the treatment help, and for
whom".

## Usage

``` r
fit_effects(
  data,
  y,
  treatment,
  x,
  id,
  time = NULL,
  scope = "both",
  subgroup = NULL,
  model = "auto",
  estimator = "native",
  treatment_type = "auto",
  reference = NULL,
  propensity = "auto",
  trim = 0.05,
  n_groups = 4L,
  conf_level = 0.95,
  test_prop = 0.3,
  min_train = 10L,
  min_test = 4L,
  ...
)
```

## Arguments

- data:

  Data frame.

- y:

  Outcome column name.

- treatment:

  Treatment column: two levels, several levels, or a dose.

- x:

  Predictors: names, numeric positions, `a:b` range, formula, or data
  frame.

- id:

  Person/unit ID column.

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

- model:

  Outcome model used for the response surfaces. Any model from
  [`fit_ml()`](https://pak.dynasite.org/idiographic/reference/fit_ml.md);
  `"auto"` picks the simple linear or logistic model for the estimator
  in use.

- estimator:

  Backend for the outcome *and* propensity models. See
  [`fit_ml()`](https://pak.dynasite.org/idiographic/reference/fit_ml.md).

- treatment_type:

  One of `"auto"`, `"binary"`, `"multiarm"`, `"continuous"`.

- reference:

  Arm to contrast against, for a multi-arm treatment. Defaults to the
  first level.

- propensity:

  Model for the treatment given the predictors. `"auto"` follows
  `estimator`. For a dose this is the `E[T|X]` regression.

- trim:

  Propensity values are held inside `[trim, 1 - trim]` so a near-zero
  denominator cannot dominate the score.

- n_groups:

  Number of sorted effect groups for GATES.

- conf_level:

  Confidence level for the reported intervals.

- test_prop:

  Proportion of each person's ordered rows held out.

- min_train:

  Minimum complete training rows per person.

- min_test:

  Minimum complete held-out rows per person.

- ...:

  Passed to the outcome models, e.g. `lambda` or `k`.

## Value

An `idiographic_effects` object, which is also an `idiographic_fit`: the
usual accessors work, and
[`effects()`](https://rdrr.io/r/stats/effects.html) returns the effect
table.

## Details

In repeated-measures data the treatment usually varies *within* a person
over time, so a person-specific treatment effect is estimable.
`fit_effects()` reports one effect per scope: the pooled effect, the
effect inside each subgroup, and the effect for each individual. Rows
with a missing treatment are removed before temporal splitting. Missing
outcome or predictor values are handled by the shared complete-case
split.

## Treatment types

The treatment type is detected from the column and can be named outright
with `treatment_type`:

- `binary`:

  Two levels, or 0/1. Estimated by **AIPW**: two response surfaces and a
  propensity model are fitted on the training rows and applied to the
  held-out rows to build one doubly robust score per row. A wrong
  outcome model or a wrong propensity model can each be tolerated – not
  both. The reported effect is `ATE`.

- `multiarm`:

  Three or more unordered arms. The same AIPW score is built for every
  arm, with a one-versus-rest propensity, and each arm is contrasted
  against `reference`. One set of effects is reported per contrast,
  distinguished by the `contrast` column.

- `continuous`:

  A dose. AIPW does not apply – there are no two surfaces to difference
  – so the estimator is the partially linear double-ML (Robinson) score:
  `E[Y|X]` and `E[T|X]` are fitted on the training rows and the effect
  is the regression of one held-out residual on the other. The reported
  effect is `APE`, the change in the outcome per **one unit** of
  treatment. **Read the note below on what it averages.**

## What `APE` averages

If the dose effect is the same for everyone, `APE` is that effect. If it
varies, `APE` is **not** the plain average `E[tau(X)]`: the partially
linear estimator returns the *variance-weighted* average

\$\$\frac{E\[\mathrm{Var}(T \mid X)\\\tau(X)\]}{E\[\mathrm{Var}(T \mid
X)\]},\$\$

which leans towards the people whose dose varies most, because they
carry the most information about its effect. The difference is not
small: with residualized doses of -1, 1, -3, 3 and true effects of 0, 0,
10, 10, the plain average is 5 while this estimator returns 9.

This is the standard target of the partially linear model and it is the
right quantity for a summary. It is simply not the same question as
"what would the average person gain from one more unit". When the dose
effect varies – and `GATES` in the same output will tell you whether it
does – report it as a projection, not as a population mean. A numeric
treatment with more than two distinct values is read as a dose. Pass
`treatment_type = "multiarm"` to treat its values as unordered arms
instead.

A two-level non-numeric outcome is modelled on the probability scale, so
the reported effect is a risk difference. A 0/1 numeric outcome is
modelled as a linear probability, which estimates the same risk
difference.

## Reported effects

- `ATE` / `APE`:

  The average treatment effect, or for a dose the average partial effect
  per unit.

- `GATES:g1..gK`:

  Sorted effect groups. Rows are ranked by their predicted effect and
  cut into `n_groups` bins; `g1` is the least-helped bin and `gK` the
  most-helped. `GATES:top-bottom` is their difference: if its confidence
  interval excludes zero, the treatment genuinely helps some more than
  others.

- `BLP:heterogeneity`:

  The slope of the held-out scores on the predicted effect. A
  significant slope means the predicted heterogeneity is real and not
  noise.

## Examples

``` r
set.seed(1)
d <- data.frame(
  id = rep(1:6, each = 40), day = rep(1:40, 6),
  x1 = rnorm(240), x2 = rnorm(240)
)
d$drug <- rbinom(240, 1, 0.5)
# The drug helps people with a high x1 and does nothing for the rest.
d$mood <- 2 * d$drug * (d$x1 > 0) + 0.5 * d$x1 + rnorm(240, sd = 0.5)

fit <- fit_effects(d, y = "mood", treatment = "drug", x = c("x1", "x2"),
                   id = "id", time = "day", scope = "pooled")
effects(fit)
#>    scope  model estimator subject subgroup            effect contrast  n
#> 1 pooled linear    native    .all     .all               ATE   1 vs 0 72
#> 2 pooled linear    native    .all     .all          GATES:g1   1 vs 0 18
#> 3 pooled linear    native    .all     .all          GATES:g2   1 vs 0 18
#> 4 pooled linear    native    .all     .all          GATES:g3   1 vs 0 18
#> 5 pooled linear    native    .all     .all          GATES:g4   1 vs 0 18
#> 6 pooled linear    native    .all     .all  GATES:top-bottom   1 vs 0 36
#> 7 pooled linear    native    .all     .all BLP:heterogeneity   1 vs 0 72
#>   n_people    estimate std_error    conf_low conf_high   statistic      p_value
#> 1        6  0.84405642 0.2754044  0.13610681 1.5520060  3.06478888 0.0279491203
#> 2        6  0.02935751 0.3720129 -0.92693200 0.9856470  0.07891531 0.9401609542
#> 3        6 -0.12413935 0.3538335 -1.03369731 0.7854186 -0.35084114 0.7400058248
#> 4        6  1.10952302 0.4013986  0.07769502 2.1413510  2.76414260 0.0396394908
#> 5        6  2.36148449 0.4128149  1.30030995 3.4226590  5.72044362 0.0022831144
#> 6        6  2.33212698 0.2210167  1.76398534 2.9002686 10.55181110 0.0001320564
#> 7        6  1.14360096 0.2190990  0.58038914 1.7068128  5.21956347 0.0034111294

# A dose rather than a switch: the effect is reported per unit of dose.
d$dose <- round(runif(240, 0, 10), 1)
d$sleep <- 0.3 * d$dose + 0.5 * d$x1 + rnorm(240, sd = 0.5)
dose_fit <- fit_effects(d, y = "sleep", treatment = "dose",
                        x = c("x1", "x2"), id = "id", time = "day",
                        scope = "pooled")
effects(dose_fit, effect = "APE")
#>    scope  model estimator subject subgroup effect contrast  n n_people
#> 1 pooled linear    native    .all     .all    APE per unit 72        6
#>    estimate std_error  conf_low conf_high statistic      p_value
#> 1 0.3158625 0.0182937 0.2688371  0.362888  17.26619 1.193544e-05
```
