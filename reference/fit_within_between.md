# Fit a within-between (hybrid) model

Puts the within-person and the between-person component of a predictor
into **one** model, so the two effects can be compared directly and the
gap between them tested. Person-centering alone cannot do this: it
estimates the within effect and discards the between effect entirely.

## Usage

``` r
fit_within_between(
  data,
  y,
  x,
  id,
  time = NULL,
  model = c("within_between", "within", "between", "contextual"),
  estimator = c("ols", "reml", "ml"),
  scope = "pooled",
  subgroup = NULL,
  random = NULL,
  cluster = NULL,
  conf_level = 0.95,
  test_prop = 0.2,
  min_train = 10L,
  min_test = 1L
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

- time:

  Optional ordering column.

- model:

  Parameterization: `"within_between"`, `"within"`, `"between"`, or
  `"contextual"`. See Details.

- estimator:

  `"ols"` (cluster-robust least squares), or `"reml"` / `"ml"` for a
  mixed model via `lme4`.

- scope:

  `"pooled"`, `"subgroup"`, or `"all"`. A between-person term is
  constant inside a person, so individual scope is available only for
  `model = "within"`.

- subgroup:

  Optional subgroup mapping: an
  [`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md)
  result, a grouping column in `data`, or a named vector of labels per
  person.

- random:

  Extra grouping columns to give random intercepts, e.g.
  `random = "course"` for a cross-classified design. Mixed estimators
  only.

- cluster:

  Column(s) to cluster standard errors on, defaulting to `id`. Up to
  two, for two-way clustering. OLS only.

- conf_level:

  Confidence level for the reported intervals.

- test_prop:

  Proportion of each person's ordered rows held out.

- min_train:

  Minimum complete training rows per person.

- min_test:

  Minimum complete held-out rows per person.

## Value

An `idiographic_wb` object, which is also an `idiographic_fit`.
[`coefs()`](https://pak.dynasite.org/idiographic/reference/coefs.md)
gains `component` and `variable` columns;
[`contextual()`](https://pak.dynasite.org/idiographic/reference/contextual.md)
returns the within/between comparison.

## Details

Each predictor `x` is split into a person mean (the between component)
and the deviation from it (the within component).

## Model parameterizations

- `within_between`:

  Both components as separate terms (the default). The contextual effect
  is their difference, tested as a contrast.

- `within`:

  The within component only – the fixed-effects estimator. The only
  parameterization that also works at individual scope.

- `between`:

  The between component only.

- `contextual`:

  The raw predictor plus the person mean. Algebraically equivalent to
  `within_between`, but the coefficient on the person mean *is* the
  contextual effect directly, rather than a contrast of two.

## Estimators

`"ols"` (the default, base R) fits by least squares with
**cluster-robust** standard errors; rows within a person are not
independent, and treating them as independent gives roughly 77% coverage
where 95% is claimed. Pass `cluster` to cluster on something other than
– or in addition to – the person; with two clustering variables the
Cameron-Gelbach-Miller two-way estimator is used, which is what a design
with people crossed by courses needs.

`"reml"` and `"ml"` fit a mixed model with `lme4` instead, adding a
random intercept for `id` and for anything named in `random`. This is
what makes a cross-classified design – `(1 | person) + (1 | course)` –
expressible, and it makes the model's variance components available
through
[`variance_components()`](https://pak.dynasite.org/idiographic/reference/variance_components.md).
The fixed-effect estimates agree closely with the OLS ones; what differs
is the standard errors and the variance decomposition.

Person means are computed on the **training** rows and applied to the
held-out rows, so the reported metrics stay honest.

## Examples

``` r
fit <- fit_within_between(srl, y = "effort", x = c("efficacy", "planning"),
                          id = "name", time = "day")
coefs(fit)
#>    scope          model estimator subject subgroup             term component
#> 1 pooled within_between       ols    .all     .all      (Intercept)     .none
#> 2 pooled within_between       ols    .all     .all  efficacy_within    within
#> 3 pooled within_between       ols    .all     .all  planning_within    within
#> 4 pooled within_between       ols    .all     .all efficacy_between   between
#> 5 pooled within_between       ols    .all     .all planning_between   between
#>   variable   estimate  std_error statistic      p_value   conf_low  conf_high
#> 1    .none 21.1716609 7.12357772  2.972054 5.321378e-03  6.7100293 35.6332925
#> 2 efficacy  0.2680674 0.04661939  5.750126 1.648335e-06  0.1734250  0.3627098
#> 3 planning  0.3319056 0.04783083  6.939157 4.578176e-08  0.2348039  0.4290074
#> 4 efficacy  0.4601588 0.13552830  3.395297 1.719875e-03  0.1850217  0.7352959
#> 5 planning  0.2257383 0.14281198  1.580668 1.229501e-01 -0.0641854  0.5156621
contextual(fit)
#>   variable   within   between   contextual     S.E.            95% CI       p
#> -----------------------------------------------------------------------------
#>   efficacy   0.2681    0.4602       0.1921   0.1361   [-0.084, 0.468]   0.167
#>   planning   0.3319    0.2257      -0.1062   0.1496   [-0.410, 0.197]   0.483
#> 
#> scope = pooled,  model = within_between,  estimator = ols,  subject = .all,  subgroup = .all

# The contextual parameterization reports the same gap as one coefficient.
fit_within_between(srl, y = "effort", x = "efficacy", id = "name",
                   model = "contextual")
#> MODEL INFO
#>   Outcome         effort
#>   Predictors      efficacy
#>   Person ID       name (36 people)
#>   Specification   contextual
#>   Estimator       OLS, cluster-robust on name
#>   Scope           pooled
#> 
#> MODEL FIT (held out)
#>   Rows        1,150
#>   RMSE        21.9825
#>   R-squared   0.3304
#> 
#> WITHIN EFFECTS
#>                Est.     S.E.   t val.        p
#> ----------------------------------------------
#>   efficacy   0.4164   0.0552     7.55   <1e-04
#> 
#> CONTEXTUAL EFFECTS (between - within)
#>                Est.     S.E.           95% CI        p
#> ------------------------------------------------------
#>   efficacy   0.2102   0.1021   [0.003, 0.417]   0.0469
#>   An interval excluding zero means the two processes differ.
```
