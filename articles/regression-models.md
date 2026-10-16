# Regression Models

Regression analyses of intensive longitudinal data can be conducted at
three levels, each allowing a different degree of heterogeneity between
persons ([López-Pernas et al. 2025](#ref-lopezpernas2025)).

At the **variable-centered** (pooled) level, one model is estimated from
the data of all persons together. The resulting coefficients describe
the average association in the sample and assume that one set of
coefficients adequately represents every person. At the
**person-centered** (subgroup) level, the sample is partitioned into
groups whose members share similar coefficient profiles, and one model
is estimated for each group. At the **person-specific** (individual)
level, a separate model is estimated for each person from that person’s
own repeated measures. No similarity between persons is assumed, and
many observations per person are required.

| Question | Function |
|:---|:---|
| What are the pooled and person-specific linear associations? | [`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md) |
| What are the pooled and person-specific binary or count associations? | [`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md) |
| Do within-person and between-person effects differ? | [`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md) |

The three functions accept a `scope` argument (`"pooled"`, `"subgroup"`,
`"individual"`, or any combination) and fit the selected levels on the
same data, so that their coefficients can be compared directly.

## `fit_lm()`

### Analytic question

[`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md)
estimates a linear model at every requested scope and returns the
results in one tidy object. The outcome, predictors, person identifier,
and time column are specified once; the `scope` argument determines how
many models are fitted. When `scope = c("pooled", "individual")`, both
the pooled model and one model per person are estimated. Pooled and
subgroup models combine the occasions of many persons, so their standard
errors are cluster-robust (sandwich-estimated), clustered on the person
identifier, rather than model-based. This ensures that the repeated
occasions of the same person are not treated as independent
observations.

### Pooled and person-specific coefficients

The example below predicts daily effort from efficacy and monitoring for
the 36 learners in the bundled `srl` data, each observed on 156 days.

``` r

lm_fit <- fit_lm(srl, y = "effort", x = c("efficacy", "monitoring"),
                 id = "name", time = "day",
                 scope = c("pooled", "individual"))
coefs(lm_fit, scope = "pooled")
#>    scope model estimator subject subgroup        term   estimate  std_error
#> 1 pooled    lm    native    .all     .all (Intercept) 27.9366297 4.64403728
#> 2 pooled    lm    native    .all     .all    efficacy  0.4415288 0.05638120
#> 3 pooled    lm    native    .all     .all  monitoring  0.1442609 0.04962956
#>   statistic      p_value
#> 1  6.015591 7.364519e-07
#> 2  7.831136 3.341992e-09
#> 3  2.906753 6.297403e-03
```

In the pooled model, estimated effort increased by 0.44 points per unit
of efficacy (SE = 0.056) and by 0.14 points per unit of monitoring (SE =
0.050). Both standard errors are cluster-robust. Because every learner
contributes to the same regression, these coefficients describe an
average association that may not hold for any individual learner
([López-Pernas et al. 2025](#ref-lopezpernas2025)).

### Subgroup evidence

Whether the learners form distinct coefficient types is an empirical
question.
[`test_subgroups()`](https://pak.dynasite.org/idiographic/reference/test_subgroups.md)
compares Gaussian mixture models with one to four components by the
Bayesian information criterion (BIC), where lower values indicate better
fit. A one-component solution is a valid outcome of the comparison: it
indicates that the coefficients are drawn from a single population
rather than discrete types.

``` r

subgroup_test <- test_subgroups(srl, y = "effort",
                                x = c("efficacy", "monitoring"),
                                id = "name", time = "day")
subgroup_test
#> Idiographic Subgroup Test
#>   People:      36
#>   Coefficients: efficacy, monitoring
#>   Searched:    k = 1..4, covariance models EII/VII/EEI/VVI/EEE/VVV
#> 
#>   VERDICT:     no subgroups detected (one population fits best)
#>                Clustering these people anyway will still return
#>                groups -- they will not mean anything.
#> 
#>   Use as.data.frame() for the BIC table.
as.data.frame(subgroup_test) |> head()
#>   k model     loglik npar      bic selected
#> 1 1   EII -101.14942    3 213.0494     TRUE
#> 2 1   VII -101.14942    3 213.0494    FALSE
#> 3 1   EEI -101.14942    4 216.6329    FALSE
#> 4 1   VVI -101.14942    4 216.6329    FALSE
#> 5 2   EEI  -96.59769    7 218.2800    FALSE
#> 6 1   EEE -100.37905    5 218.6757    FALSE
```

The one-population model had the lowest BIC (213.0); the best
two-component model reached 218.3. The learners therefore did not
separate into subgroups, and a subgroup model would effectively
reproduce the pooled model. The differences between learners were
continuous, with no evidence of discrete types.

### Person-specific coefficients

The individual scope returns one coefficient per learner. Sorting the
efficacy slopes reveals the spread of person-specific associations.

``` r

coefs(lm_fit, scope = "individual", term = "efficacy", sort_by = "estimate")
#>         scope model estimator subject subgroup     term    estimate  std_error
#> 1  individual    lm    native    Ravi    .none efficacy -0.17593246 0.06588666
#> 2  individual    lm    native  Fatima    .none efficacy -0.07446370 0.10746158
#> 3  individual    lm    native  Astrid    .none efficacy -0.05395851 0.09879602
#> 4  individual    lm    native     Mei    .none efficacy -0.04712054 0.13516693
#> 5  individual    lm    native   Grace    .none efficacy -0.04644204 0.09655782
#> 6  individual    lm    native  Takumi    .none efficacy -0.03050483 0.05578008
#> 7  individual    lm    native   Diana    .none efficacy -0.02878219 0.12819848
#> 8  individual    lm    native  Ingrid    .none efficacy  0.04525204 0.03775940
#> 9  individual    lm    native    Yuki    .none efficacy  0.05668378 0.12381736
#> 10 individual    lm    native  Saanvi    .none efficacy  0.06555265 0.10201863
#> 11 individual    lm    native      Li    .none efficacy  0.09274654 0.06361575
#> 12 individual    lm    native    Noor    .none efficacy  0.09948594 0.06293399
#> 13 individual    lm    native   Freja    .none efficacy  0.10768334 0.09462269
#> 14 individual    lm    native  Hassan    .none efficacy  0.11078082 0.07467859
#> 15 individual    lm    native   Frank    .none efficacy  0.11661877 0.14873655
#> 16 individual    lm    native   Aisha    .none efficacy  0.22096514 0.08212755
#> 17 individual    lm    native   Heidi    .none efficacy  0.26046909 0.11301647
#> 18 individual    lm    native  Sakura    .none efficacy  0.32162255 0.09173958
#> 19 individual    lm    native    Nils    .none efficacy  0.32217056 0.04833643
#> 20 individual    lm    native   Bjorn    .none efficacy  0.32370947 0.07776339
#> 21 individual    lm    native Charlie    .none efficacy  0.36267341 0.11691383
#> 22 individual    lm    native     Eve    .none efficacy  0.39750968 0.06893480
#> 23 individual    lm    native    Sven    .none efficacy  0.39823498 0.09074932
#> 24 individual    lm    native    Judy    .none efficacy  0.41343609 0.09675454
#> 25 individual    lm    native    Ivan    .none efficacy  0.41383992 0.07628228
#> 26 individual    lm    native   Alice    .none efficacy  0.45430413 0.07660304
#> 27 individual    lm    native   Layla    .none efficacy  0.48129512 0.10733407
#> 28 individual    lm    native   Anika    .none efficacy  0.49238804 0.10132704
#> 29 individual    lm    native    Erik    .none efficacy  0.54619060 0.11380460
#> 30 individual    lm    native    Zain    .none efficacy  0.55734985 0.07696641
#> 31 individual    lm    native     Bob    .none efficacy  0.58204703 0.08782432
#> 32 individual    lm    native Hiroshi    .none efficacy  0.58346849 0.04139897
#> 33 individual    lm    native     Liv    .none efficacy  0.65131368 0.08435553
#> 34 individual    lm    native   Karin    .none efficacy  0.66415300 0.16266735
#> 35 individual    lm    native    Omar    .none efficacy  0.78811972 0.08832974
#> 36 individual    lm    native    Lars    .none efficacy  0.86816107 0.09969809
#>     statistic      p_value
#> 1  -2.6702288 8.621903e-03
#> 2  -0.6929333 4.897016e-01
#> 3  -0.5461607 5.859611e-01
#> 4  -0.3486099 7.279880e-01
#> 5  -0.4809765 6.314018e-01
#> 6  -0.5468767 5.854706e-01
#> 7  -0.2245127 8.227370e-01
#> 8   1.1984312 2.330912e-01
#> 9   0.4578016 6.479160e-01
#> 10  0.6425556 5.217281e-01
#> 11  1.4579178 1.474538e-01
#> 12  1.5807982 1.165786e-01
#> 13  1.1380287 2.573568e-01
#> 14  1.4834348 1.405590e-01
#> 15  0.7840627 4.345355e-01
#> 16  2.6905118 8.143071e-03
#> 17  2.3047003 2.288778e-02
#> 18  3.5058210 6.392827e-04
#> 19  6.6651702 8.302748e-10
#> 20  4.1627490 5.918110e-05
#> 21  3.1020575 2.392108e-03
#> 22  5.7664584 6.329566e-08
#> 23  4.3882973 2.457258e-05
#> 24  4.2730409 3.865056e-05
#> 25  5.4251122 3.019172e-07
#> 26  5.9306278 2.933652e-08
#> 27  4.4840852 1.697788e-05
#> 28  4.8593941 3.568461e-06
#> 29  4.7993721 4.593763e-06
#> 30  7.2414684 4.484880e-11
#> 31  6.6274018 1.074165e-09
#> 32 14.0937925 2.740016e-27
#> 33  7.7210551 3.701746e-12
#> 34  4.0828908 8.019725e-05
#> 35  8.9224726 5.905342e-15
#> 36  8.7079007 1.895113e-14
```

The person-specific efficacy slopes ranged from -0.18 (Ravi) to 0.87
(Lars), with a median of 0.32. Seven of the 36 learners had negative
slopes, and only eight had a slope within 0.10 of the pooled value of
0.44. The spread of these slopes contains both true between-person
differences and sampling error, because each slope is estimated from a
limited number of occasions.

### Coefficient heterogeneity

[`pool_coefs()`](https://pak.dynasite.org/idiographic/reference/pool_coefs.md)
separates true heterogeneity from sampling error by fitting a
DerSimonian–Laird random-effects model to the person-specific
coefficients . The function reports the uncertainty-weighted pooled
slope, the standard deviation of the true slopes ($`\tau`$), and the
share of the observed spread attributable to true between-person
differences ($`I^2`$).

``` r

pool_coefs(lm_fit)
#> POOLED PERSON EFFECTS
#>   Method   random effects (DerSimonian-Laird)
#>   People   36
#>   Terms    3
#> 
#>   term           k    pooled           95% CI   sd_obs      tau      I2      Q p
#> --------------------------------------------------------------------------------
#>   (Intercept)   36   31.9792   [22.59, 41.37]   23.432   27.054   0.968   <1e-04
#>   efficacy      36    0.2871     [0.20, 0.38]    0.271    0.252   0.912   <1e-04
#>   monitoring    36    0.1957     [0.09, 0.30]    0.299    0.276   0.919   <1e-04
#> 
#>   sd_obs = observed spread;  tau = spread of the true coefficients
#>   I2     = share of the observed spread that is real
```

For efficacy, the pooled slope was 0.29 (95% CI: 0.20 to 0.38), the
estimated $`\tau`$ was 0.25, and $`I^2`$ was 0.91. Under a normal
approximation, the true slopes of 95% of learners lie between
approximately \$-\$0.20 and 0.78 — a range that includes learners for
whom efficacy is unrelated to effort. The pooling and shrinkage vignette
covers
[`pool_coefs()`](https://pak.dynasite.org/idiographic/reference/pool_coefs.md)
and
[`shrink_coefs()`](https://pak.dynasite.org/idiographic/reference/shrink_coefs.md)
in greater detail.

``` r

plot_coefs(lm_fit, term = "efficacy")
```

![Figure 1. Person-specific efficacy slopes with 95% confidence
intervals. The dashed line marks the pooled slope; the shaded band
covers the interval expected to contain 95% of the true
slopes.](regression-models_files/figure-html/lm-plot-1.png)

Figure 1. Person-specific efficacy slopes with 95% confidence intervals.
The dashed line marks the pooled slope; the shaded band covers the
interval expected to contain 95% of the true slopes.

## `fit_glm()`

### Analytic question

[`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md)
extends the same three-level framework to binary and count outcomes
through a generalized linear model. The `family` argument accepts
`"binomial"` for binary outcomes, `"poisson"` for counts, and `"negbin"`
for overdispersed counts. Pooled and subgroup standard errors are again
cluster-robust.

The bundled `submissions` data are simulated: 40 learners observed on 80
days, with a binary record of whether an assignment was submitted each
day. The learners belong to two types. For the 20 engaged learners, the
log-odds of submitting rise with daily motivation (true slope 1.2); for
the 20 avoidant learners, they fall (true slope \$-\$0.6). Each
learner’s slope varies slightly around the slope of the type, and the
`type` column records the true type.

``` r

head(submissions)
#>   learner day    type motivation submitted
#> 1       1   1 engaged  1.3284155         1
#> 2       1   2 engaged  1.5540090         1
#> 3       1   3 engaged -0.3463324         0
#> 4       1   4 engaged  0.3191570         1
#> 5       1   5 engaged -2.3165814         0
#> 6       1   6 engaged -0.1089408         0
```

### Pooled coefficients

``` r

pooled_glm <- fit_glm(submissions, y = "submitted", x = "motivation",
                       id = "learner", family = "binomial",
                       time = "day", scope = "pooled")
coefs(pooled_glm)
#>    scope    model estimator subject subgroup        term   estimate  std_error
#> 1 pooled binomial    native    .all     .all (Intercept) -0.1210932 0.08797027
#> 2 pooled binomial    native    .all     .all  motivation  0.2297620 0.12060291
#>   statistic    p_value
#> 1 -1.376524 0.16865944
#> 2  1.905111 0.05676559
```

The pooled motivation slope was 0.23 (SE = 0.12, $`p`$ = .057). Averaged
over both types, motivation appeared weakly related to submission — a
coefficient that describes neither type of learner accurately. This is
the expected consequence of pooling across processes with opposite
signs.

### Subgroup discovery

[`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md)
first applies the mixture comparison internally (equivalent to
[`test_subgroups()`](https://pak.dynasite.org/idiographic/reference/test_subgroups.md))
and, when a multi-component representation is supported, assigns each
learner to a group. Assignment stability is estimated through repeated
resampling.

``` r

set.seed(1)
submission_groups <- find_subgroups(submissions, y = "submitted",
                                    x = "motivation", id = "learner",
                                    time = "day", k = "auto", reps = 30)
submission_groups
#> Idiographic Subgroups
#>   Method:      effect_clustering
#>   Subgroups:   2 (chosen automatically)
#>   People:      40
#>   Sizes:       g1=21, g2=19
#>   Stability:   0.92 (how reproducible the partition is --
#>                NOT evidence that the subgroups are real)
#> 
#>   VERDICT:     2 subgroups (mixture BIC beats one group by 23.9: very strong evidence)
#> 
#>   Use groups(), test_subgroups(), fit_subgroups()
```

Two subgroups were selected (BIC improvement of 23.9 over a single
population). The partition coincided with the simulated types for 39 of
the 40 learners. The subgroup assignment then enters
[`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md)
through the `subgroup` argument, so that pooled, subgroup, and
individual models are estimated together.

``` r

glm_fit <- fit_glm(submissions, y = "submitted", x = "motivation",
                    id = "learner", family = "binomial", time = "day",
                    scope = c("pooled", "subgroup", "individual"),
                    subgroup = submission_groups)
coefs(glm_fit, scope = "subgroup")
#>      scope    model estimator subject subgroup        term   estimate
#> 1 subgroup binomial    native    .all       g1 (Intercept) -0.2698968
#> 2 subgroup binomial    native    .all       g1  motivation -0.4353766
#> 3 subgroup binomial    native    .all       g2 (Intercept) -0.1201561
#> 4 subgroup binomial    native    .all       g2  motivation  1.1744905
#>    std_error statistic      p_value
#> 1 0.09741277 -2.770651 5.594442e-03
#> 2 0.10230837 -4.255533 2.085518e-05
#> 3 0.08109624 -1.481649 1.384338e-01
#> 4 0.06605776 17.779749 1.014329e-70
```

The subgroup motivation slopes were \$-\$0.44 and 1.17, close to the
generating values of \$-\$0.6 and 1.2. The person-centered level
recovered the two processes that the pooled coefficient had averaged
away.

### Person-specific estimates

``` r

coefs(glm_fit, scope = "individual", term = "motivation", sort_by = "estimate")
#>         scope    model estimator subject subgroup       term    estimate
#> 1  individual binomial    native      40    .none motivation -1.37624783
#> 2  individual binomial    native      38    .none motivation -1.07654492
#> 3  individual binomial    native      37    .none motivation -1.04348110
#> 4  individual binomial    native      33    .none motivation -0.95085967
#> 5  individual binomial    native      21    .none motivation -0.92332346
#> 6  individual binomial    native      23    .none motivation -0.79106709
#> 7  individual binomial    native      28    .none motivation -0.77808416
#> 8  individual binomial    native      29    .none motivation -0.76873372
#> 9  individual binomial    native      35    .none motivation -0.71768974
#> 10 individual binomial    native      24    .none motivation -0.61911355
#> 11 individual binomial    native      34    .none motivation -0.43571092
#> 12 individual binomial    native      22    .none motivation -0.40896956
#> 13 individual binomial    native      31    .none motivation -0.39829537
#> 14 individual binomial    native      39    .none motivation -0.33277437
#> 15 individual binomial    native      25    .none motivation -0.32523418
#> 16 individual binomial    native      26    .none motivation -0.32152487
#> 17 individual binomial    native      30    .none motivation -0.16367880
#> 18 individual binomial    native      36    .none motivation -0.04107140
#> 19 individual binomial    native      15    .none motivation  0.04752350
#> 20 individual binomial    native      32    .none motivation  0.08457889
#> 21 individual binomial    native      27    .none motivation  0.24431938
#> 22 individual binomial    native       6    .none motivation  0.61402089
#> 23 individual binomial    native      10    .none motivation  0.66592781
#> 24 individual binomial    native      19    .none motivation  0.95483789
#> 25 individual binomial    native       4    .none motivation  0.96193326
#> 26 individual binomial    native       5    .none motivation  1.04983624
#> 27 individual binomial    native      14    .none motivation  1.05494868
#> 28 individual binomial    native       8    .none motivation  1.07810338
#> 29 individual binomial    native      18    .none motivation  1.08337945
#> 30 individual binomial    native      17    .none motivation  1.08746481
#> 31 individual binomial    native      12    .none motivation  1.13480749
#> 32 individual binomial    native       7    .none motivation  1.15516965
#> 33 individual binomial    native      11    .none motivation  1.20721594
#> 34 individual binomial    native       3    .none motivation  1.22151136
#> 35 individual binomial    native       2    .none motivation  1.28773478
#> 36 individual binomial    native      13    .none motivation  1.31565920
#> 37 individual binomial    native       9    .none motivation  1.57844380
#> 38 individual binomial    native      16    .none motivation  1.62468680
#> 39 individual binomial    native      20    .none motivation  1.90811934
#> 40 individual binomial    native       1    .none motivation  1.91277263
#>    std_error  statistic      p_value
#> 1  0.4485916 -3.0679302 0.0021554696
#> 2  0.3330985 -3.2319117 0.0012296505
#> 3  0.3126110 -3.3379535 0.0008439786
#> 4  0.3638110 -2.6136088 0.0089591551
#> 5  0.3361402 -2.7468401 0.0060172470
#> 6  0.3762876 -2.1022935 0.0355275712
#> 7  0.3120727 -2.4932783 0.0126569602
#> 8  0.3011687 -2.5525021 0.0106952252
#> 9  0.2919978 -2.4578605 0.0139767471
#> 10 0.3304076 -1.8737870 0.0609597827
#> 11 0.2697114 -1.6154708 0.1062087895
#> 12 0.3370252 -1.2134688 0.2249506315
#> 13 0.2568290 -1.5508191 0.1209450316
#> 14 0.3006467 -1.1068617 0.2683537115
#> 15 0.2996294 -1.0854547 0.2777203031
#> 16 0.2736620 -1.1748978 0.2400356057
#> 17 0.2382671 -0.6869551 0.4921110511
#> 18 0.2822659 -0.1455061 0.8843113363
#> 19 0.2968993  0.1600661 0.8728290221
#> 20 0.2407232  0.3513534 0.7253232681
#> 21 0.2646522  0.9231715 0.3559178576
#> 22 0.3380394  1.8164179 0.0693062860
#> 23 0.3495095  1.9053209 0.0567383674
#> 24 0.3461373  2.7585524 0.0058057989
#> 25 0.3131100  3.0721899 0.0021249447
#> 26 0.3036189  3.4577440 0.0005447188
#> 27 0.3397214  3.1053348 0.0019006378
#> 28 0.3495837  3.0839636 0.0020426261
#> 29 0.4076014  2.6579387 0.0078620184
#> 30 0.3153980  3.4479127 0.0005649367
#> 31 0.3727702  3.0442548 0.0023325750
#> 32 0.3934850  2.9357401 0.0033275298
#> 33 0.4275811  2.8233614 0.0047522968
#> 34 0.3789641  3.2232905 0.0012672695
#> 35 0.4323771  2.9782681 0.0028988233
#> 36 0.3813290  3.4501947 0.0005601824
#> 37 0.4223806  3.7370181 0.0001862156
#> 38 0.4280768  3.7953165 0.0001474552
#> 39 0.4606353  4.1423642 0.0000343744
#> 40 0.5540106  3.4525919 0.0005552283
```

The person-specific slopes ranged from \$-\$1.38 to 1.91. Each learner’s
model estimates that learner’s slope from the 80 available occasions,
with the precision that sample size allows.

### Coefficient heterogeneity

``` r

pool_coefs(glm_fit)
#> POOLED PERSON EFFECTS
#>   Method   random effects (DerSimonian-Laird)
#>   People   40
#>   Terms    2
#> 
#>   term           k    pooled           95% CI   sd_obs     tau      I2       Q p
#> --------------------------------------------------------------------------------
#>   (Intercept)   40   -0.1641   [-0.30, -0.03]    0.423   0.261   0.409   0.00446
#>   motivation    40    0.2641    [-0.04, 0.57]    0.959   0.790   0.853   < 1e-04
#> 
#>   sd_obs = observed spread;  tau = spread of the true coefficients
#>   I2     = share of the observed spread that is real
```

The random-effects pooled motivation slope was 0.26 (95% CI: \$-\$0.04
to 0.57), the estimated $`\tau`$ was 0.79, and $`I^2`$ was 0.85. The
large $`\tau`$ mainly reflects the distance between the two subgroups:
the random-effects model describes the slopes with a single normal
distribution, whereas the true generating distribution is bimodal.

``` r

plot_coefs(glm_fit, term = "motivation")
```

![Figure 2. Person-specific motivation slopes with 95% confidence
intervals. The dashed line marks the pooled slope; the shaded band
covers the interval expected to contain 95% of the true
slopes.](regression-models_files/figure-html/glm-plot-1.png)

Figure 2. Person-specific motivation slopes with 95% confidence
intervals. The dashed line marks the pooled slope; the shaded band
covers the interval expected to contain 95% of the true slopes.

### Assumptions and failure checks

Several conditions determine the validity of the results above.

1.  **Independence of persons.** Cluster-robust standard errors correct
    for within-person dependence but assume that persons are
    independent. Nested designs (learners within classrooms) require an
    additional clustering level.
2.  **Sufficient occasions.** Person-specific models require enough
    complete rows per person for estimation and for a meaningful
    held-out block. Persons with too few observations are recorded in
    the failure table rather than silently dropped.
3.  **Outcome distribution.** The binomial family assumes a binary
    outcome coded as 0/1 or as a two-level factor. Overdispersed counts
    should be modelled with `"negbin"` rather than `"poisson"`, because
    the Poisson assumption of equal mean and variance produces standard
    errors that are too small when violated.
4.  **Coefficient comparability.** Pooling with
    [`pool_coefs()`](https://pak.dynasite.org/idiographic/reference/pool_coefs.md)
    and subgroup discovery with
    [`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md)
    require person-specific coefficients that are on the same scale.
    Differing predictors, coding, or transformations across persons
    invalidate comparisons.

## `fit_within_between()`

### Analytic question

A regression on the raw scores of a repeated-measures variable conflates
two associations: the association between a person’s daily deviations
from their own average (within-person), and the association between
persons’ long-run averages (between-person) ([Saqr et al.
2024](#ref-saqr2024)). Whether these two associations differ is an
empirical question with substantive implications. A within-person effect
of efficacy on effort describes how effort changes on days when efficacy
is above or below a learner’s own typical level. A between-person effect
describes whether learners who are generally more efficacious also tend
to exert more effort.

[`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md)
separates each predictor into its within-person and between-person parts
— by person-mean centring the raw scores and including the person means
as separate predictors — and estimates a slope for each part. The
[`contextual()`](https://pak.dynasite.org/idiographic/reference/contextual.md)
accessor reports both slopes and their difference, which indicates
whether the between-person association exceeds (or falls short of) the
within-person association.

### Contextual effects

``` r

wb_fit <- fit_within_between(srl, y = "effort",
                             x = c("efficacy", "monitoring"),
                             id = "name", time = "day")
contextual(wb_fit)
#>   variable     within   between   contextual     S.E.            95% CI        p
#> --------------------------------------------------------------------------------
#>   efficacy     0.3688    0.5862       0.2174   0.1015    [0.011, 0.423]   0.0392
#>   monitoring   0.1745    0.0978      -0.0767   0.0988   [-0.277, 0.124]   0.4427
#> 
#> scope = pooled,  model = within_between,  estimator = ols,  subject = .all,  subgroup = .all
```

For efficacy, the within-person slope was 0.37 and the between-person
slope was 0.59. The difference of 0.22 (95% CI: 0.01 to 0.42, $`p`$ =
.039) indicates a stronger association between learners than within
them: learners who were generally more efficacious tended to exert
disproportionately more effort than would be expected from the
within-person relation alone. For monitoring, the within-person slope
was 0.17 and the between-person slope was 0.10; the difference of
\$-\$0.08 (95% CI: \$-\$0.28 to 0.12, $`p`$ = .44) was not
distinguishable from zero.

### Visualisation

``` r

plot_components(wb_fit)
```

![Figure 3. Within-person and between-person slopes with 95% confidence
intervals.](regression-models_files/figure-html/wb-plot-1.png)

Figure 3. Within-person and between-person slopes with 95% confidence
intervals.

### Assumptions and failure checks

The decomposition requires that variation exists at both levels. A
variable with no between-person variance (ICC near zero) has no
between-person component to estimate; a variable constant within every
person has no within-person component. The
[`variance_components()`](https://pak.dynasite.org/idiographic/reference/variance_components.md)
function, described in the descriptives vignette, reports the ICC for
each variable.

The contextual effect is an associational difference, not a causal
estimate. The between-person slope is identified under the assumption
that no time-invariant confounders jointly predict the outcome and the
person-level predictor mean. When that assumption is untenable, the
within-person slope remains identified under weaker conditions (no
time-varying confounders), whereas the between-person slope and the
contextual difference absorb unobserved between-person confounding.

## Choice among the three functions

[`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md)
and
[`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md)
estimate associations at pooled, subgroup, and individual levels. The
choice between the two depends on the outcome distribution: continuous
for
[`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md),
binary or count for
[`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md).

[`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md)
separates within-person and between-person associations in the pooled
regression. It addresses the question of whether the relation observed
on days when a person deviates from their own average matches the
relation observed across persons who differ in their averages. A
substantial contextual effect indicates that the raw pooled coefficient
is a weighted average of two different quantities.

Prediction accuracy at the individual level is examined in the
prediction vignette with
[`fit_ml()`](https://pak.dynasite.org/idiographic/reference/fit_ml.md).
Subgroup discovery and treatment-effect heterogeneity are covered in the
subgroups and effects vignette with
[`test_subgroups()`](https://pak.dynasite.org/idiographic/reference/test_subgroups.md),
[`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md),
and
[`fit_effects()`](https://pak.dynasite.org/idiographic/reference/fit_effects.md).
Coefficient synthesis and stabilisation are covered in the pooling and
shrinkage vignette with
[`pool_coefs()`](https://pak.dynasite.org/idiographic/reference/pool_coefs.md)
and
[`shrink_coefs()`](https://pak.dynasite.org/idiographic/reference/shrink_coefs.md).

## References

López-Pernas, Sonsoles, Halil Kayaduman, Leonie V. D. E. Vogelsmeier,
and Mohammed Saqr. 2025. “The Three Levels of Analysis:
Variable-Centered, Person-Centered and Person-Specific Analysis in
Education.” Chap. 19 in *Advanced Learning Analytics Methods: AI,
Precision and Complexity*. Springer Nature Switzerland.
<https://doi.org/10.1007/978-3-031-54464-4_19>.

Saqr, Mohammed, Leonie V. Vogelsmeier, and Sonsoles López-Pernas. 2024.
“Capturing Where the Learning Process Takes Place: A Person-Specific and
Person-Centered Primer.” *Learning and Individual Differences* 113:
102492.
