# 1. Getting started with idiographic

`idiographic` estimates **person-specific** and **within-person**
networks from intensive longitudinal data. It implements ordinary VAR,
graphical VAR, subject-by-subject VARs, mlVAR, uSEM, and GIMME as
clean-room estimators, plus rolling networks, edge stability, forecast
validation, and model comparison.

Every estimator returns an object that

- **prints** a compact, readable summary that *shows the estimated
  networks*,
- exposes **one tidy verb per question** —
  [`edges()`](https://saqr.me/idiographic/reference/edges.md),
  [`nodes()`](https://saqr.me/idiographic/reference/nodes.md),
  [`summary()`](https://rdrr.io/r/base/summary.html),
  [`coefs()`](https://saqr.me/idiographic/reference/coefs.md),
  [`matrices()`](https://saqr.me/idiographic/reference/matrices.md) —
  each returning a plain `data.frame` you print directly, and
- **plots** with a single
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) call.

This vignette covers the shared data and the preprocessing audit. Each
method has its own vignette:

| Method                  | Vignette                            |
|-------------------------|-------------------------------------|
| Ordinary VAR            | *Ordinary VAR*                      |
| Graphical VAR           | *Graphical VAR*                     |
| One network per person  | *Subject-by-subject networks*       |
| mlVAR                   | *Multilevel VAR (mlVAR)*            |
| uSEM                    | *Unified SEM (uSEM)*                |
| GIMME                   | *GIMME*                             |
| Rolling / time-varying  | *Rolling networks*                  |
| Stability & forecasting | *Stability and forecast validation* |
| Comparing estimators    | *Comparing methods*                 |

``` r

library(idiographic)
```

## The data

The package ships the self-regulated-learning (SRL) experience-sampling
data from Chapter 20 of the *Learning Analytics Methods* book as a
ready-to-model dataset. Loading it needs no ordering, indexing, or
column selection — the rows are already ordered by `name` then `day`,
and `day` is a within-person occasion index you can hand straight to
[`build_usem()`](https://saqr.me/idiographic/reference/build_usem.md) or
[`build_gimme()`](https://saqr.me/idiographic/reference/build_gimme.md).

``` r

data(srl)

summary(srl)
#>         name           day            efficacy          value       
#>  Length   :5616   Min.   :  1.00   Min.   :  0.00   Min.   :  0.00  
#>  N.unique :  36   1st Qu.: 39.75   1st Qu.: 35.38   1st Qu.: 38.46  
#>  N.blank  :   0   Median : 78.50   Median : 56.25   Median : 59.18  
#>  Min.nchar:   2   Mean   : 78.50   Mean   : 54.02   Mean   : 56.57  
#>  Max.nchar:   7   3rd Qu.:117.25   3rd Qu.: 75.00   3rd Qu.: 76.92  
#>                   Max.   :156.00   Max.   :100.00   Max.   :100.00  
#>                                    NAs    :6        NAs    :13      
#>     planning        monitoring         effort          control      
#>  Min.   :  0.00   Min.   :  0.00   Min.   :  0.00   Min.   :  0.00  
#>  1st Qu.: 37.50   1st Qu.: 23.91   1st Qu.: 40.98   1st Qu.: 28.21  
#>  Median : 58.62   Median : 52.00   Median : 62.69   Median : 55.81  
#>  Mean   : 56.83   Mean   : 49.09   Mean   : 58.99   Mean   : 52.75  
#>  3rd Qu.: 79.37   3rd Qu.: 73.26   3rd Qu.: 80.95   3rd Qu.: 77.27  
#>  Max.   :100.00   Max.   :100.00   Max.   :100.00   Max.   :100.00  
#>  NAs    :4        NAs    :5        NAs    :8        NAs    :10      
#>       help            social         organizing    
#>  Min.   :  0.00   Min.   :  0.00   Min.   :  0.00  
#>  1st Qu.: 42.86   1st Qu.: 34.04   1st Qu.: 37.04  
#>  Median : 66.27   Median : 60.00   Median : 57.69  
#>  Mean   : 62.10   Mean   : 56.54   Mean   : 55.49  
#>  3rd Qu.: 84.44   3rd Qu.: 81.67   3rd Qu.: 77.36  
#>  Max.   :100.00   Max.   :100.00   Max.   :100.00  
#>  NAs    :12       NAs    :69       NAs    :4
```

Thirty-six students each contributed 156 occasions on nine SRL
indicators:

``` r

nrow(srl)
#> [1] 5616
length(unique(srl$name))
#> [1] 36
head(srl)
#>    name day efficacy    value planning monitoring   effort  control help social
#> 1 Aisha   1 38.23529 58.33333  0.00000  34.210526 53.96825 39.39394   78   60.0
#> 2 Aisha   2 14.70588 47.22222 50.00000   7.894737 79.36508 45.45455   16   10.0
#> 3 Aisha   3 67.64706 52.77778 52.27273  19.736842 77.77778 39.39394   28   55.0
#> 4 Aisha   4 55.88235 63.88889 65.90909  22.368421 93.65079 42.42424   24   47.5
#> 5 Aisha   5 55.88235 36.11111 52.27273  22.368421 71.42857 57.57576   48   57.5
#> 6 Aisha   6 44.11765 61.11111 52.27273  57.894737 82.53968 42.42424   28   62.5
#>   organizing
#> 1   1.612903
#> 2  61.290323
#> 3  77.419355
#> 4  37.096774
#> 5  75.806452
#> 6  30.645161
```

Throughout the method vignettes we use a focused set of five indicators
so the printed networks stay readable; all nine are available.

``` r

vars <- c("efficacy", "value", "planning", "monitoring", "effort")
```

The chapter uses `Grace` for the single-person examples, and we keep
that convention. Where a method needs a single series, pass
`subject = "Grace"` to the estimator rather than slicing the data frame
yourself.

## Preprocessing audit

Before fitting dynamic models,
[`audit_preprocess()`](https://saqr.me/idiographic/reference/audit_preprocess.md)
builds the same lag-1 design the estimators use and reports missingness,
day-boundary drops, trends, AR(1) persistence, split-half drift, and a
unit-root screen. It does not fit a network; it makes the modelling
input explicit.

``` r

audit <- audit_preprocess(srl, vars = vars, id = "name", min_obs = 100)

audit
#> Idiographic Preprocessing Audit
#>   Variables:      5 (efficacy, value, planning, monitoring, effort)
#>   Ordered rows:   5616
#>   Retained pairs: 5548
#>   Trend flags:    10
#>   High AR flags:  0
#>   Drift flags:    1
#>   Unit-root risk: 0
#>   Zero variance:  0
#>   Tables:         x$pairs | x$counts | x$diagnostics
```

The audit’s tidy tables are accessible directly — one row per
subject-by-variable for the diagnostics, one row per subject-by-day for
the counts:

``` r

head(as.data.frame(audit))
#>   subject   variable   n n_observed missing_prop          mean        sd
#> 1   Aisha   efficacy 156        156            0 -4.105373e-18 0.7864311
#> 2   Aisha      value 156        156            0 -4.863620e-18 0.7808769
#> 3   Aisha   planning 156        156            0 -1.790984e-17 0.7960943
#> 4   Aisha monitoring 156        156            0 -5.486775e-17 0.8119451
#> 5   Aisha     effort 156        156            0  3.560353e-17 0.6716902
#> 6   Alice   efficacy 156        156            0 -2.352076e-17 0.7707262
#>     trend_slope    trend_t    trend_p        ar1     ar1_t      ar1_p
#> 1  0.0020047874  1.4387618 0.15224731 0.17105142 2.1197072 0.03564446
#> 2  0.0028145228  2.0480445 0.04225412 0.19466449 2.4477593 0.01550576
#> 3  0.0033425823  2.3974897 0.01770558 0.01132701 0.1437627 0.88587704
#> 4 -0.0021372375 -1.4862801 0.13924943 0.05212035 0.6457137 0.51943200
#> 5  0.0003149294  0.2629199 0.79296371 0.13136714 1.6434829 0.10233648
#> 6 -0.0004679022 -0.3404868 0.73395399 0.02395697 0.2965123 0.76724098
#>   mean_first_half mean_second_half  mean_shift mean_shift_std mean_shift_p
#> 1     -0.15014485       0.15014485  0.30028969     0.38183852   0.01662736
#> 2     -0.13884210       0.13884210  0.27768420     0.35560563   0.02589611
#> 3     -0.14812463       0.14812463  0.29624926     0.37212836   0.01963663
#> 4      0.05589524      -0.05589524 -0.11179048     0.13768231   0.39162241
#> 5     -0.01096234       0.01096234  0.02192467     0.03264105   0.83926300
#> 6      0.02977691      -0.02977691 -0.05955382     0.07726976   0.63094960
#>   sd_first_half sd_second_half sd_ratio unit_root_coef unit_root_t
#> 1     0.8207057      0.7250859 1.131874     -0.8289486   -10.27252
#> 2     0.7410516      0.7995273 1.078909     -0.8053355   -10.12649
#> 3     0.7874451      0.7818193 1.007196     -0.9886730   -12.54827
#> 4     0.8246748      0.8004082 1.030318     -0.9478796   -11.74318
#> 5     0.5607006      0.7704325 1.374053     -0.8686329   -10.86713
#> 6     0.7751904      0.7700882 1.006625     -0.9760430   -12.08036
#>   flag_zero_variance flag_trend flag_high_ar flag_mean_shift flag_sd_shift
#> 1              FALSE      FALSE        FALSE           FALSE         FALSE
#> 2              FALSE       TRUE        FALSE           FALSE         FALSE
#> 3              FALSE       TRUE        FALSE           FALSE         FALSE
#> 4              FALSE      FALSE        FALSE           FALSE         FALSE
#> 5              FALSE      FALSE        FALSE           FALSE         FALSE
#> 6              FALSE      FALSE        FALSE           FALSE         FALSE
#>   flag_unit_root flag_stationarity_risk
#> 1          FALSE                  FALSE
#> 2          FALSE                   TRUE
#> 3          FALSE                   TRUE
#> 4          FALSE                  FALSE
#> 5          FALSE                  FALSE
#> 6          FALSE                  FALSE

head(audit$counts)
#>   subject day n_rows n_lag_possible n_complete_pairs n_retained
#> 1   Aisha   1    156            155              155        155
#> 2   Alice   1    156            155              155        155
#> 3   Anika   1    156            155              155        155
#> 4  Astrid   1    156            155              155        155
#> 5   Bjorn   1    156            155              155        155
#> 6     Bob   1    156            155              149        149
#>   n_boundary_dropped
#> 1                  1
#> 2                  1
#> 3                  1
#> 4                  1
#> 5                  1
#> 6                  1
```

## Where to go next

Pick the method vignette that matches your question. A good first stop
is *Ordinary VAR*: it is the transparent OLS baseline that every other
temporal estimator can be read against.
