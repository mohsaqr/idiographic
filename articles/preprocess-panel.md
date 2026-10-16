# Preparing Panel Data

Repeated-measures data are usually transformed before modelling. This
vignette covers three transformations: separating each variable into its
between-person and within-person parts, creating lagged variables, and
removing time trends. Each transformation is computed separately for
each person and in time order. The examples use the 36 learners in the
`srl` data, each observed on 156 days.

## Within-person and between-person decomposition

Each repeated measure has two parts. The between-person part is the
stable average across all occasions. The within-person part is the
fluctuation of each occasion around that stable average. Differences
between persons in their stable averages form the between-person
variation; the fluctuations form the within-person variation. An
analysis of the raw scores, whether across all occasions or at a single
occasion, mixes the two, and its result can resemble the within-person
association, the between-person association, or neither, depending on
how much of each variable is stable and how much fluctuates. Separating
the two parts allows each association to be estimated on its own.

For a variable $`x`$ observed for person $`i`$ at occasion $`t`$,
[`split_levels()`](https://pak.dynasite.org/idiographic/reference/split_levels.md)
computes the between-person part as the mean of that person’s observed
values,
``` math
\bar{x}_i = \frac{1}{T_i}\sum_{t=1}^{T_i} x_{it},
```
where $`T_i`$ is the number of occasions on which $`x`$ was observed.
The within-person part is the deviation of each observation from that
mean, $`x_{it} - \bar{x}_i`$. The two parts sum to the original score.
For efficacy, the between-person part is stored as `efficacy_between`
and the within-person part as `efficacy_within`.

``` r

split_levels(srl, id = "name", vars = "efficacy", time = "day", keep_all = FALSE) |> head()
#>    name day efficacy efficacy_within efficacy_between
#> 1 Aisha   1 38.23529      -18.684012         56.91931
#> 2 Aisha   2 14.70588      -42.213424         56.91931
#> 3 Aisha   3 67.64706       10.727753         56.91931
#> 4 Aisha   4 55.88235       -1.036953         56.91931
#> 5 Aisha   5 55.88235       -1.036953         56.91931
#> 6 Aisha   6 44.11765      -12.801659         56.91931
```

To see how effort relates to each part, both parts are used as
predictors in the same regression. The slope of `efficacy_within` shows
how effort changes on days when a learner’s efficacy is above or below
that learner’s average. The slope of `efficacy_between` shows how effort
differs between learners with higher and lower average efficacy.
[`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md)
performs the split and the regression in one step. Because each learner
contributes many days, its standard errors are adjusted for the repeated
observations of the same learner.

``` r

wb_fit <- fit_within_between(srl, y = "effort", x = "efficacy", id = "name", time = "day")
coefs(wb_fit)
#>    scope          model estimator subject subgroup             term component
#> 1 pooled within_between       ols    .all     .all      (Intercept)     .none
#> 2 pooled within_between       ols    .all     .all  efficacy_within    within
#> 3 pooled within_between       ols    .all     .all efficacy_between   between
#>   variable   estimate  std_error statistic      p_value   conf_low  conf_high
#> 1    .none 25.0284934 6.64097196  3.768800 6.059592e-04 11.5466036 38.5103833
#> 2 efficacy  0.4163891 0.05518059  7.545934 7.650039e-09  0.3043665  0.5284116
#> 3 efficacy  0.6266185 0.10584994  5.919876 9.845147e-07  0.4117317  0.8415053
```

The within-person slope was 0.42 (95% CI 0.30 to 0.53). On days when a
learner’s efficacy was 10 points above that learner’s average, effort
was about 4 points higher. The between-person slope was 0.63 (95% CI
0.41 to 0.84). Learners whose average efficacy was 10 points higher
reported about 6 points more effort on average. The between-person
interval is wider because it rests on 36 learners, while the
within-person slope draws on all of their days.

Whether the two slopes differ is tested directly by their difference,
which
[`contextual()`](https://pak.dynasite.org/idiographic/reference/contextual.md)
reports.

``` r

contextual(wb_fit)
#>   variable   within   between   contextual     S.E.           95% CI        p
#> -----------------------------------------------------------------------------
#>   efficacy   0.4164    0.6266       0.2102   0.1021   [0.003, 0.417]   0.0469
#> 
#> scope = pooled,  model = within_between,  estimator = ols,  subject = .all,  subgroup = .all
```

The between-person slope exceeded the within-person slope by 0.21 (95%
CI 0.003 to 0.42, p = .047). The interval barely excludes zero, so the
evidence that the two slopes differ is weak.

## Lagged variables

A lagged variable holds the value of a variable on the preceding
occasion. With `lag = 1`, the column `efficacy_lag1` contains, in each
row, the learner’s efficacy on the previous day. Lagged variables allow
a model to test whether a state on one day predicts an outcome on the
next, for example whether efficacy yesterday predicts effort today.

Lags are computed within persons, so the first occasion of each person
has a missing lagged value, as shown below for the first days of Aisha.

``` r

preprocess_panel(srl, id = "name", time = "day", vars = "efficacy", lag = 1, keep_all = FALSE) |> head()
#>    name day efficacy efficacy_lag1
#> 1 Aisha   1 38.23529            NA
#> 2 Aisha   2 14.70588      38.23529
#> 3 Aisha   3 67.64706      14.70588
#> 4 Aisha   4 55.88235      67.64706
#> 5 Aisha   5 55.88235      55.88235
#> 6 Aisha   6 44.11765      55.88235
```

A lag refers to the preceding occasion regardless of the time elapsed
between occasions. For irregularly spaced occasions, `lag_max_gap` sets
the lagged value to missing when the preceding occasion lies further
back than a specified interval.

## Detrending

`preprocess_panel(detrend = "person")` removes the linear time trend of
each person’s series when the trend is significant at `detrend_alpha`
(0.05 by default). The presence of trends is assessed beforehand with
the trend estimates reported by
[`describe_persons()`](https://pak.dynasite.org/idiographic/reference/describe_persons.md).

``` r

trends <- describe_persons(srl, id = "name", time = "day", vars = "efficacy:organizing", detail = "full")
summary(trends)
#>     variable persons mean_of_means sd_of_means mean_sd_within
#> 1    control      36      52.75783    18.45740       22.84994
#> 2   efficacy      36      54.03965    15.90734       21.27906
#> 3     effort      36      58.97604    14.54039       22.25366
#> 4       help      36      62.07208    18.17278       20.59724
#> 5 monitoring      36      49.11049    21.00157       21.10374
#> 6 organizing      36      55.49354    15.95229       22.35608
#> 7   planning      36      56.84187    14.86661       21.97606
#> 8     social      36      56.64708    21.02848       21.07529
#> 9      value      36      56.55765    14.53585       22.03823
#>   significant_trends trend_share
#> 1                  2  0.05555556
#> 2                  1  0.02777778
#> 3                  1  0.02777778
#> 4                  0  0.00000000
#> 5                  1  0.02777778
#> 6                  1  0.02777778
#> 7                  5  0.13888889
#> 8                  3  0.08333333
#> 9                  2  0.05555556
```

Across the nine variables, 16 of the 324 person-by-variable series
(4.9%) had a significant linear trend, the proportion expected from
false positives at the 0.05 level if no series trended. Detrending these
data would therefore modify a small number of series largely at random.
Detrending is warranted when significant trends are considerably more
frequent than the significance level, or when the design implies a
trend, as in intervention or developmental studies. Series without a
fixed slope, such as random walks, require differencing, which
`preprocess(detrend = "auto")` applies to the affected series only.

## Centring and scaling

Person-centring (`center = "person"`) retains only the within-person
part and discards the between-person part;
[`split_levels()`](https://pak.dynasite.org/idiographic/reference/split_levels.md)
retains both, so the two options are not combined. Person scaling
(`scale = "person"`) divides each person’s values by that person’s
standard deviation, which places persons who fluctuate to different
degrees on a common scale. Grand scaling (`scale = "grand"`) uses a
single standard deviation for all persons.

[`preprocess_panel()`](https://pak.dynasite.org/idiographic/reference/preprocess_panel.md)
and
[`split_levels()`](https://pak.dynasite.org/idiographic/reference/split_levels.md)
compute these quantities from all occasions of each person. Model
functions that hold out later occasions for testing, such as
[`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md),
compute them from the training occasions only.
