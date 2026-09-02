# From Raw Panel Data to Person-Specific Conclusions

`idiographic` treats the person as the primary analytical unit. This
vignette shows the common path from inspecting repeated observations to
comparing person-specific conclusions. Network methods use the same
person-by-time data contract and are covered in the method-specific
vignettes.

## Inspect the panel

The bundled `srl` data contain daily observations nested within
learners.

``` r

vars <- c("efficacy", "monitoring", "effort")

describe_persons(srl, id = "name", vars = vars, time = "day", n = 6)
#> PERSON DESCRIPTIVES
#>   Grouping    name
#>   Time        day
#>   People      6
#>   Variables   1
#> 
#>   subject   variable     n   miss     mean   median       sd      min       max    rmssd   autocor      span   gap_median   gap_max
#> -----------------------------------------------------------------------------------------------------------------------------------
#>   Aisha     efficacy   156      0   56.919   61.765   21.034    0.000   100.000   26.881     0.169   155.000        1.000     1.000
#>   Alice     efficacy   156      0   35.761   36.364   20.614    0.000   100.000   28.790     0.024   155.000        1.000     1.000
#>   Anika     efficacy   156      0   50.099   47.692   19.373    0.000   100.000   28.656    -0.124   155.000        1.000     1.000
#>   Astrid    efficacy   156      0   72.401   78.378   20.078   10.811   100.000   28.496    -0.008   155.000        1.000     1.000
#>   Bjorn     efficacy   156      0   52.707   51.852   21.803    3.704   100.000   30.443     0.023   155.000        1.000     1.000
#>   Bob       efficacy   154      2   78.219   77.108   16.717    0.000   100.000   23.209     0.028   155.000        1.000     1.000
#> 
#>   sd    = overall spread;  rmssd = occasion-to-occasion change
#>   autocor = lag-1 carry-over (inertia)
correlate_persons(srl, id = "name", vars = vars, n = 6)
#> PERSON-SPECIFIC CORRELATIONS
#>   Grouping   name
#>   People     2
#>   Pairs      3
#> 
#>   subject   x            y              n        r           95% CI          p
#> ------------------------------------------------------------------------------
#>   Aisha     efficacy     monitoring   156    0.394     [0.25, 0.52]    < 1e-04
#>   Aisha     efficacy     effort       156    0.352     [0.21, 0.48]    < 1e-04
#>   Aisha     monitoring   effort       156    0.284     [0.13, 0.42]   0.000325
#>   Alice     efficacy     monitoring   156   -0.231   [-0.37, -0.08]   0.003736
#>   Alice     efficacy     effort       156    0.491     [0.36, 0.60]    < 1e-04
#>   Alice     monitoring   effort       156   -0.352   [-0.48, -0.21]    < 1e-04
variance_components(srl, id = "name", vars = vars)
#> VARIANCE COMPONENTS
#>   Grouping   name
#>   Method     anova
#> 
#>                  Within    Between     ICC   Reliability
#> --------------------------------------------------------
#>   efficacy     472.5379   249.7267   0.346         0.988
#>   monitoring   467.1183   437.6607   0.484         0.993
#>   effort       522.5017   207.7688   0.285         0.984
#> 
#>   ICC         share of variance lying BETWEEN groups
#>   Reliability precision of each group's own mean
```

The descriptive layer reports each person’s usable observations,
missingness, variation, serial dependence, and sampling gaps. Inspecting
these quantities before fitting helps distinguish a model failure from a
panel that cannot identify the requested person-specific effect.

## Prepare within-person variables

[`preprocess_panel()`](https://pak.dynasite.org/idiographic/reference/preprocess_panel.md)
transforms columns without crossing person boundaries. The example adds
a person-centred predictor and its previous-occasion value.

``` r

panel <- preprocess_panel(
  srl,
  id = "name",
  time = "day",
  vars = c("efficacy", "monitoring"),
  center = "person",
  lag = 1
)
```

Use
[`preprocess()`](https://pak.dynasite.org/idiographic/reference/preprocess.md)
instead when the goal is the established network-readiness audit
(stationarity, compliance, variance, and related diagnostics).

## Compare pooled and individual estimates

The default scope fits a pooled comparison and one model per person.
Ordered hold-out validation uses the final observations of each person
as test rows.

``` r

fit <- fit_lm(
  panel,
  y = "effort",
  x = c("efficacy", "monitoring", "efficacy_lag1"),
  id = "name",
  time = "day",
  scope = "both",
  min_train = 30
)

metrics(fit, overall = TRUE)
#>        scope model estimator  subject subgroup    n     rmse      mae      bias
#> 1     pooled    lm    native .overall     .all 1150 24.45330 20.48970 0.5741532
#> 2 individual    lm    native .overall     .all 1150 18.79467 14.55597 0.3911686
#>   r_squared
#> 1 0.1714338
#> 2 0.5105349
coefs(fit, scope = "individual", n = 8)
#>        scope model estimator subject subgroup          term     estimate
#> 1 individual    lm    native   Aisha    .none   (Intercept) 77.325111113
#> 2 individual    lm    native   Aisha    .none      efficacy  0.211722912
#> 3 individual    lm    native   Aisha    .none    monitoring  0.154777528
#> 4 individual    lm    native   Aisha    .none efficacy_lag1 -0.002918768
#> 5 individual    lm    native   Alice    .none   (Intercept) 60.422756642
#> 6 individual    lm    native   Alice    .none      efficacy  0.456545348
#> 7 individual    lm    native   Alice    .none    monitoring -0.327781383
#> 8 individual    lm    native   Alice    .none efficacy_lag1 -0.108543860
#>    std_error   statistic      p_value
#> 1 1.58108831 48.90625681 1.201203e-80
#> 2 0.08470843  2.49943131 1.380211e-02
#> 3 0.06946865  2.22801977 2.775848e-02
#> 4 0.07567714 -0.03856869 9.692989e-01
#> 5 1.55462437 38.86646687 1.801465e-69
#> 6 0.07646448  5.97068534 2.509109e-08
#> 7 0.08063487 -4.06500768 8.657107e-05
#> 8 0.07428774 -1.46112756 1.466159e-01
```

`individuals(fit)`, `pooled(fit)`, `person(fit, id)`, and `overall(fit)`
create focused views without changing the underlying estimates.

## Separate within-person and between-person effects

Raw panel regressions can mix two different questions: whether people
with a higher typical predictor value have a higher outcome, and whether
a person has a higher outcome than usual when their predictor is higher
than usual.

``` r

wb <- fit_within_between(
  srl,
  y = "effort",
  x = c("efficacy", "monitoring"),
  id = "name",
  time = "day",
  scope = "pooled",
  min_train = 30
)

contextual(wb)
#>   variable     within   between   contextual     S.E.            95% CI        p
#> --------------------------------------------------------------------------------
#>   efficacy     0.3688    0.5862       0.2174   0.1015    [0.011, 0.423]   0.0392
#>   monitoring   0.1745    0.0978      -0.0767   0.0988   [-0.277, 0.124]   0.4427
#> 
#> scope = pooled,  model = within_between,  estimator = ols,  subject = .all,  subgroup = .all
```

The contextual table keeps these components explicit rather than
silently assigning one interpretation to a raw-score coefficient.

## Stabilise and explain differences between people

Individual coefficients vary because processes differ and because
estimates are noisy. Pooling estimates the coefficient distribution;
shrinkage produces stabilised person-specific coefficients.

``` r

pooled_coefs <- pool_coefs(fit)
shrunk_coefs <- shrink_coefs(fit)

pooled_coefs
#> POOLED PERSON EFFECTS
#>   Method   random effects (DerSimonian-Laird)
#>   People   36
#>   Terms    4
#> 
#>   term             k    pooled           95% CI   sd_obs      tau      I2      Q p
#> ----------------------------------------------------------------------------------
#>   (Intercept)     36   58.9356   [53.50, 64.38]   14.418   15.982   0.991   <1e-04
#>   efficacy        36    0.2890     [0.20, 0.38]    0.269    0.251   0.910   <1e-04
#>   monitoring      36    0.1956     [0.09, 0.30]    0.297    0.272   0.915   <1e-04
#>   efficacy_lag1   36    0.0222    [-0.01, 0.05]    0.092    0.031   0.159    0.204
#> 
#>   sd_obs = spread you see;  tau = spread that is REAL
#>   I2     = share of the observed spread that is real
head(shrunk_coefs)
#> SHRUNKEN PERSON EFFECTS
#>   People   6
#>   Terms    1
#> 
#>   subject   term              raw     S.E.   weight   shrunken
#> --------------------------------------------------------------
#>   Aisha     (Intercept)   77.3251   1.5811    0.990    77.1469
#>   Alice     (Intercept)   60.4228   1.5546    0.991    60.4088
#>   Anika     (Intercept)   47.0761   1.8153    0.987    47.2271
#>   Astrid    (Intercept)   68.5023   1.6127    0.990    68.4059
#>   Bjorn     (Intercept)   52.1594   1.7829    0.988    52.2427
#>   Bob       (Intercept)   73.1308   1.4604    0.992    73.0133
#> 
#>   weight = how much of the person's own estimate is kept
```

Subgroup and treatment-effect workflows follow the same principle: test
what the data identify, retain person-level uncertainty and failures,
and use pooled quantities as comparisons rather than replacements for
individual processes. See
[`test_subgroups()`](https://pak.dynasite.org/idiographic/reference/test_subgroups.md),
[`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md),
[`fit_effects()`](https://pak.dynasite.org/idiographic/reference/fit_effects.md),
and
[`fit_heterogeneity()`](https://pak.dynasite.org/idiographic/reference/fit_heterogeneity.md)
for those analyses.

## Move to dynamic networks when the question is multivariate

When the target is a system of lagged and contemporaneous relations
rather than one outcome, use the network estimators on the same panel:

``` r

net <- fit_mlvar(
  srl,
  vars = c("efficacy", "monitoring", "effort"),
  id = "name",
  beep = "day"
)

edges(net)
coefs(net)
```

The regression and network layers deliberately share
[`coefs()`](https://pak.dynasite.org/idiographic/reference/coefs.md) and
a common idiographic vocabulary while retaining result structures
appropriate to their different estimands.
