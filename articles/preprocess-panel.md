# Preparing panel data

Intensive longitudinal data record the same persons on many occasions,
and the questions they address concern processes within persons, such as
whether the state of a person on one occasion relates to other states of
that person on the same or the following occasion. Raw scores are an
imperfect basis for these questions. Each raw score combines the stable
level at which a person typically stands with the deviation of the
occasion from that level, so an association computed on raw scores mixes
a between-person association with a within-person association. The two
associations answer different questions and can differ in size and in
sign ([Curran and Bauer 2011](#ref-curran2011); [Hoffman and Stawski
2009](#ref-hoffman2009)). A raw score also holds no information about
earlier occasions, while any claim about temporal precedence requires
the state on one occasion to be paired with a later state of the same
person. Scores that change systematically over the study period, through
learning, fatigue or habituation, share that change across variables,
and a shared trend produces an association between two variables whose
occasion-to-occasion fluctuations are independent.

Panel preparation removes these sources of bias before modelling. The
decomposition of a variable separates its between-person and
within-person components, a lagged variable pairs each occasion with the
preceding occasion of the same person, and detrending removes a linear
change over the study period. Each transformation is computed separately
for each person and in time order.

The examples use the 36 learners in `srl`, each observed on 156 days.

## Within-person and between-person decomposition

A variable measured repeatedly varies between persons and within
persons. A learner can report high efficacy on most days because high
efficacy is a stable characteristic of that learner, and the same
learner reports higher efficacy on some days than on others. The two
sources of variation correspond to different mechanisms. The
between-person association concerns stable differences, whether learners
who are generally more efficacious also generally invest more effort.
The within-person association concerns a process, whether a learner
invests more effort on days when that learner feels more efficacious
than usual. The first characterises a population of persons and the
second characterises the functioning of each person, and the inference
from one to the other holds only under restrictive conditions ([Molenaar
2004](#ref-molenaar2004)).

A regression of raw scores estimates a weighted combination of the two
slopes, with weights given by the share of the predictor’s variance at
each level ([Curran and Bauer 2011](#ref-curran2011)). When the two
slopes differ, the pooled slope matches neither, and its value depends
on the composition of the sample. Entering the person mean and the
deviation from it as separate predictors resolves this conflation
([Mundlak 1978](#ref-mundlak1978); [Hoffman and Stawski
2009](#ref-hoffman2009)). The deviation is uncorrelated with the person
mean by construction. Its slope is therefore a within-person estimate
that is unaffected by any stable characteristic of the person, whether
measured or unmeasured, which is the property of the fixed-effects
estimator.

For a variable $`x`$ observed for person $`i`$ at occasion $`t`$, the
between-person component is the person mean, the mean of that person’s
observed values,
``` math
\bar{x}_i = \frac{1}{T_i}\sum_{t=1}^{T_i} x_{it},
```
where $`T_i`$ is the number of occasions on which $`x`$ was observed.
The within-person component is the person-mean-centred score
$`x_{it} - \bar{x}_i`$, the deviation of each occasion from the person
mean, and the two components sum to the original score.
[`split_levels()`](https://pak.dynasite.org/idiographic/reference/split_levels.md)
adds both components to the data as variables, for efficacy as
`efficacy_between` and `efficacy_within`.

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

The between-person component `efficacy_between` and the within-person
component `efficacy_within` enter the same regression as predictors of
effort. The slope of `efficacy_within` is the within-person effect, the
change in effort on days when a learner’s efficacy deviates from that
learner’s mean. The slope of `efficacy_between` is the between-person
effect, the difference in mean effort between learners whose mean
efficacy differs.
[`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md)
estimates the regression on the first 124 days of each learner and holds
out the last 32 days to evaluate its predictions, and the person means
are computed from the estimation days only. The 4,464 estimation days
are nested in 36 learners, and observations of the same learner are
correlated. Standard errors that treat the observations as independent
understate the uncertainty, so the standard errors are clustered on the
learner ([Liang and Zeger 1986](#ref-liang1986)).

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

The within-person slope is 0.42 (95% CI 0.30 to 0.53). On days when a
learner’s efficacy is 10 points above that learner’s mean, effort is
about 4 points higher. The between-person slope is 0.63 (95% CI 0.41 to
0.84). Learners whose mean efficacy is 10 points higher report about 6
points more effort on average. The between-person interval is wider
because its precision depends on the number of learners, 36, while the
within-person slope draws on the daily deviations of all learners.

The difference between the between-person and the within-person slope is
the contextual effect ([Mundlak 1978](#ref-mundlak1978)). It measures
the association of the person mean with the outcome beyond the
association implied by the within-person slope. A positive contextual
effect indicates that learners with higher mean efficacy invest more
effort than their daily relation between efficacy and effort predicts,
which is consistent with stable characteristics, such as motivation or
prior achievement, that raise both mean efficacy and mean effort.

``` r

contextual(wb_fit)
#>   variable   within   between   contextual     S.E.           95% CI        p
#> -----------------------------------------------------------------------------
#>   efficacy   0.4164    0.6266       0.2102   0.1021   [0.003, 0.417]   0.0469
#> 
#> scope = pooled,  model = within_between,  estimator = ols,  subject = .all,  subgroup = .all
```

The between-person slope exceeds the within-person slope by 0.21 (95% CI
0.003 to 0.42, p = .047). The lower bound of the interval lies close to
zero, and the evidence for a difference between the two slopes is weak.

## Lagged variables

Many hypotheses about within-person processes concern effects that
unfold over time, such as whether the efficacy of a learner on one day
predicts the effort of that learner on the following day. A test of such
a hypothesis requires a predictor measured before the outcome. Temporal
precedence is also a necessary condition for a causal interpretation.
Two variables measured at the same time can each be the cause of the
other, whereas a variable measured earlier can only act on a later
outcome. A lagged variable establishes this order by pairing each
observation with the preceding observation of the same person. With
`lag = 1`, the column `efficacy_lag1` holds, in each row, the efficacy
of the learner on the preceding day.

The pairing yields two kinds of lagged effect. The autoregressive
effect, the slope of a variable on its own lagged value, measures the
persistence of a state from one occasion to the next, often termed
inertia. The cross-lagged effect, the slope of one variable on the
lagged value of another, measures whether a deviation in one state
precedes a deviation in the other, for example whether efficacy above a
learner’s mean on one day predicts effort above the mean on the next
day. These two effects are the parameters of the vector autoregressive
models that underlie dynamic networks ([Bringmann et al.
2013](#ref-bringmann2013); [Epskamp et al.
2018](#ref-epskamp2018mlvar)). Precedence is a necessary condition and
remains insufficient on its own, since a third variable that changes
before both can produce a cross-lagged association.

Lags are computed within persons, so each lagged value comes from the
same person as the row it occupies. The first observation of each person
has no preceding observation and receives a missing lagged value, as the
first days of Aisha show.

``` r

lagged <- preprocess_panel(srl, id = "name", time = "day", vars = "efficacy", lag = 1, keep_all = FALSE)
head(lagged)
#>    name day efficacy efficacy_lag1
#> 1 Aisha   1 38.23529            NA
#> 2 Aisha   2 14.70588      38.23529
#> 3 Aisha   3 67.64706      14.70588
#> 4 Aisha   4 55.88235      67.64706
#> 5 Aisha   5 55.88235      55.88235
#> 6 Aisha   6 44.11765      55.88235
```

Of the 5,616 lagged values, 42 are missing, 36 for the first days of the
learners and 6 for days that follow a day without an efficacy rating.

The size of a lagged effect depends on the interval between occasions.
An effect that unfolds within hours appears stronger over a lag of one
hour than over a lag of one day, and lagged effects are therefore
comparable only between designs with similar intervals ([Gollob and
Reichardt 1987](#ref-gollob1987)). A lag refers to the preceding
occasion whatever the elapsed time, which is appropriate when occasions
are evenly spaced, as the consecutive days in `srl` are for every
learner. In designs with irregular spacing, such as experience sampling
at random times or diaries with skipped days, `lag_max_gap` sets the
lagged value to missing when the preceding occasion lies further back
than a specified interval, so that a lag spanning several days stays out
of a model of day-to-day effects.

## Detrending

The within-person models of the later vignettes assume that each series
is stationary, with a mean and a variance that stay constant over the
study period. A series that rises or falls systematically violates this
assumption. Its deviations from the person mean are then dominated by
the trend, negative early in the study and positive late in the study,
and an autoregressive model attributes the resulting dependence between
neighbouring occasions to the persistence of the state. When two
variables share a trend, their deviations correlate across occasions
whatever their day-to-day relation, a spurious association well
documented for time series ([Granger and Newbold
1974](#ref-granger1974)). Detrending regresses the series of each person
on time and retains the residuals, so that the within-person component
expresses the fluctuation around the trajectory of the person ([Wang and
Maxwell 2015](#ref-wang2015)).

Removing a trend is a substantive decision. A trend can be a nuisance,
such as a gradual habituation to the questionnaire, or the phenomenon of
interest, such as a growth in efficacy over a course. In the second case
detrending removes the effect under study, and time belongs in the model
as a predictor.

`preprocess_panel(detrend = "person")` fits a linear trend to the series
of each person and removes it when the slope is significant at
`detrend_alpha`, 0.05 by default. The presence of trends is assessed
beforehand with the trend tests that
[`describe_persons()`](https://pak.dynasite.org/idiographic/reference/describe_persons.md)
reports for each person and variable.

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
(4.9%) have a significant linear trend. With 324 tests at the 0.05 level
and no trend in any series, about 16 significant results are expected by
chance. The observed count therefore gives no evidence of systematic
trends, and detrending these data would alter a small number of series
largely at random. Detrending is warranted when significant trends are
considerably more frequent than the significance level, or when the
design implies a trend, as in intervention or developmental studies.

A linear detrend suits a deterministic trend, a steady change in the
mean. A stochastic trend, as in a random walk, wanders without a fixed
slope and is removed by differencing, the replacement of each value by
its change from the preceding occasion. `preprocess(detrend = "auto")`
tests each series for both kinds of trend and applies linear detrending
or differencing to the flagged series only.

## Centring and scaling

Centring subtracts a mean from each score. The mean that is subtracted
decides whether the differences between persons remain in the scores,
and therefore whether a slope estimated on the centred scores is a
within-person effect. Person-centring (`center = "person"`) subtracts
the person mean from each score and retains only the within-person
component. It is the appropriate transformation when the research
question concerns within-person processes alone, as in dynamic network
models. In a multilevel autoregressive model, lagged predictors left
uncentred carry the between-person differences in level, and the
autoregressive effect then mixes the persistence of daily states with
the stable differences between persons ([Hamaker and Grasman
2015](#ref-hamaker2015)). Grand-mean centring (`center = "grand"`)
subtracts one mean computed over all persons and occasions. It gives the
intercept the interpretation of the expected outcome at the sample mean
and leaves the between-person differences in the scores, so a slope on
grand-mean-centred scores remains the combination of the within-person
and the between-person slope ([Enders and Tofighi
2007](#ref-enders2007)). Person-centring and decomposition are
alternatives, because person-centring discards the between-person
component that decomposition retains, and
[`preprocess_panel()`](https://pak.dynasite.org/idiographic/reference/preprocess_panel.md)
refuses a request for both.

Scaling sets the unit of a variable. Person scaling (`scale = "person"`)
divides the scores of each person by that person’s standard deviation.
Slopes then express change in standard deviations of the person, which
makes them comparable across persons who fluctuate to different degrees.
In `srl`, the within-person standard deviation of efficacy ranges from
14.7 to 34.5 points across learners. Person scaling also removes these
differences in variability, and within-person variability is itself an
individual difference with substantive meaning, such as emotional
instability. A slope on person-scaled scores combines the strength of an
association with the variability of the predictor and reports the two as
one quantity. Grand scaling (`scale = "grand"`) divides all scores by
one standard deviation, which changes the unit of measurement and
preserves the differences in variability between persons.

[`preprocess_panel()`](https://pak.dynasite.org/idiographic/reference/preprocess_panel.md)
and
[`split_levels()`](https://pak.dynasite.org/idiographic/reference/split_levels.md)
compute person means, standard deviations and trends from all occasions
of each person. When a model is evaluated on held-out occasions,
quantities computed from all occasions carry information from the
held-out occasions into the estimation and inflate the measured
predictive accuracy.
[`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md)
therefore computes the person means from the estimation occasions only
and applies them to the held-out occasions, and the transformations of
[`preprocess_panel()`](https://pak.dynasite.org/idiographic/reference/preprocess_panel.md)
are suited to descriptive analyses and to models estimated without
held-out occasions.

## References

Bringmann, Laura F., Nathalie Vissers, Marieke Wichers, et al. 2013. “A
Network Approach to Psychopathology: New Insights into Clinical
Longitudinal Data.” *PLoS ONE* 8 (4): e60188.

Curran, Patrick J., and Daniel J. Bauer. 2011. “The Disaggregation of
Within-Person and Between-Person Effects in Longitudinal Models of
Change.” *Annual Review of Psychology* 62: 583–619.
<https://doi.org/10.1146/annurev.psych.093008.100356>.

Enders, Craig K., and Davood Tofighi. 2007. “Centering Predictor
Variables in Cross-Sectional Multilevel Models: A New Look at an Old
Issue.” *Psychological Methods* 12 (2): 121–38.
<https://doi.org/10.1037/1082-989X.12.2.121>.

Epskamp, Sacha, Lourens J. Waldorp, René Mõttus, and Denny Borsboom.
2018. “The Gaussian Graphical Model in Cross-Sectional and Time-Series
Data.” *Multivariate Behavioral Research* 53 (4): 453–80.

Gollob, Harry F., and Charles S. Reichardt. 1987. “Taking Account of
Time Lags in Causal Models.” *Child Development* 58 (1): 80–92.
<https://doi.org/10.2307/1130293>.

Granger, C. W. J., and P. Newbold. 1974. “Spurious Regressions in
Econometrics.” *Journal of Econometrics* 2 (2): 111–20.
<https://doi.org/10.1016/0304-4076(74)90034-7>.

Hamaker, Ellen L., and Raoul P. P. P. Grasman. 2015. “To Center or Not
to Center? Investigating Inertia with a Multilevel Autoregressive
Model.” *Frontiers in Psychology* 5: 1492.
<https://doi.org/10.3389/fpsyg.2014.01492>.

Hoffman, Lesa, and Robert S. Stawski. 2009. “Persons as Contexts:
Evaluating Between-Person and Within-Person Effects in Longitudinal
Analysis.” *Research in Human Development* 6 (2–3): 97–120.
<https://doi.org/10.1080/15427600902911189>.

Liang, Kung-Yee, and Scott L. Zeger. 1986. “Longitudinal Data Analysis
Using Generalized Linear Models.” *Biometrika* 73 (1): 13–22.
<https://doi.org/10.1093/biomet/73.1.13>.

Molenaar, Peter C. M. 2004. “A Manifesto on Psychology as Idiographic
Science: Bringing the Person Back into Scientific Psychology, This Time
Forever.” *Measurement: Interdisciplinary Research and Perspectives* 2
(4): 201–18. <https://doi.org/10.1207/s15366359mea0204_1>.

Mundlak, Yair. 1978. “On the Pooling of Time Series and Cross Section
Data.” *Econometrica* 46 (1): 69–85. <https://doi.org/10.2307/1913646>.

Wang, Lijuan Peggy, and Scott E. Maxwell. 2015. “On Disaggregating
Between-Person and Within-Person Effects with Longitudinal Data Using
Multilevel Models.” *Psychological Methods* 20 (1): 63–83.
<https://doi.org/10.1037/met0000030>.
