# 8. GIMME

Group iterative multiple model estimation (GIMME) sits at the boundary
of idiographic and group inference. It estimates a person-specific
unified structural equation model for each individual — one structural
model per person, fitted to that person’s own ordered series — while
searching for paths that recur in a sufficient proportion of individuals
and promoting those to a shared group level. The estimand is therefore
double: every subject receives an idiographic dynamic model, and the
group model records which pieces of structure the sample holds in
common. Like the other lag-one models in this package, it presumes
weakly stationary series, linear lag-one dynamics, and correctly
ordered, approximately equally spaced occasions within each person.

Two kinds of within-person path enter the search. A temporal path
`from -> to` is a directed lag-one path within a person’s series: the
value of `from` at occasion $`t-1`$ predicts the value of `to` at
occasion $`t`$, holding the other lagged variables constant. A
contemporaneous path is a directed within-occasion path: `from` predicts
`to` at the same occasion, over and above what the lagged variables
explain. Unlike the graphical VAR, whose contemporaneous layer is an
undirected partial-correlation network, GIMME places directed SEM paths
within an occasion as well as across occasions. The weight displayed on
a GIMME edge is the proportion of subjects whose individual model
carries that path — path prevalence — not a regression coefficient; a
weight of 1 states that every subject has the path and by itself says
nothing about the size or sign of the effect. The per-person
coefficients live in the individual models and are reported separately.

This placement distinguishes GIMME from its neighbours. Multilevel VAR
([`fit_mlvar()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar.md))
pools all subjects into a single fixed-effect average temporal matrix
and treats person-level departures as random effects around it; GIMME
instead keeps one structural model per person and asks which paths
replicate. Unified SEM
([`fit_usem()`](https://mohsaqr.github.io/idiographic/reference/fit_usem.md))
fits the same person-specific model class for a single subject, with no
group search; GIMME is the multi-subject extension that adds the
replication rule. The method is appropriate when theory expects both
shared pathways and person-specific deviations, and when the question is
which is which.

## Data and preprocessing

The estimator expects long format: one row per person-occasion, an id
column, an ordering column, and numeric time-varying indicators. The
supplied anonymized `esm_srl` data hold momentary
self-regulated-learning indicators for 41 students; `name` identifies
the student and `occasion` orders measurements within student. Five
indicators enter the model: `efficacy`, `value`, `planning`,
`monitoring`, and `effort`. To keep the vignette fast without
hand-picking people for their fitted networks, the example uses the
eight students with the most complete five-indicator occasions, breaking
ties alphabetically.

``` r

vars <- c("efficacy", "value", "planning", "monitoring", "effort")
complete_n <- tapply(complete.cases(esm_srl[vars]), esm_srl$name, sum)
selection <- data.frame(subject = names(complete_n),
                        complete = as.integer(complete_n))
selection <- selection[order(-selection$complete, selection$subject), ]
selected_ids <- head(selection$subject, 8)
head(selection, 8)
#>    subject complete
#> 15    Hana       79
#> 17    Iker       79
#> 19   Jamal       79
#> 29    Omar       79
#> 32   Quinn       79
#> 40    Yara       79
#> 5     Cira       78
#> 10    Enzo       78
preprocess(esm_srl[esm_srl$name %in% selected_ids, ],
           vars = vars, id = "name")
#> Idiographic Preprocessing
#>   Variables:      5 (efficacy, value, planning, monitoring, effort)
#>   Ordered rows:   630
#>   Retained pairs: 622
#>   Trend flags:    21
#>   High AR flags:  0
#>   Drift flags:    12
#>   Unit-root risk: 0
#>   Zero variance:  0
#>   Tables:         x$pairs | x$counts | x$diagnostics
#> 
#> 21 of 40 subject-series show a trend or unit-root that can bias the temporal network. preprocess() only diagnosed this; to clean just the series that need it, re-run with:
#>   preprocess(data = esm_srl[esm_srl$name %in% selected_ids, ], vars = vars, id = "name", detrend = "auto")
```

The transparent rule selects Hana, Iker, Jamal, Omar, Quinn, Yara, Cira,
and Enzo: six have 79 complete occasions and two have 78. The audit is
shown rather than silently assuming stationarity; these supplied series
contain trend or shift flags, so the fit is a method demonstration and
its paths should not be treated as confirmatory substantive findings.

## Fitting the model

The estimator takes the data, the variable set, the id column, and the
time column; `time = "occasion"` orders occasions within each student.
`ar = TRUE` places an autoregressive path on every variable in every
subject’s model from the outset, which anchors the search.
`groupcutoff = 0.75` and `subcutoff = 0.75` require a path to improve
fit in at least 75 percent of the relevant subjects — here, six of the
eight — before it is promoted by the corresponding rule.

``` r

students <- esm_srl[esm_srl$name %in% selected_ids, ]
gimme_fit <- fit_gimme(
  students, vars = vars, id = "name", time = "occasion",
  ar = TRUE, groupcutoff = 0.75, subcutoff = 0.75, seed = 1
)
gimme_fit
#> GIMME Network Analysis
#> ------------------------------ 
#> Subjects:   8 
#> Variables:  5  ( efficacy, value, planning, monitoring, effort )
#> AR paths:   yes 
#> Hybrid:     no 
#> 
#> Group-level paths found: 0 
#> 
#> Individual-level paths:  mean 5.1, range 2-9
#> 
#> Proportion of subjects with each path:
#> 
#>   Temporal [directed]
#>     weights [0.125, 1.000]  |  +13 / -0 edges
#>                efficacy value planning monitoring effort
#>     efficacy       1.00  0.00     0.25       0.12   0.00
#>     value          0.25  1.00     0.00       0.00   0.12
#>     planning       0.00  0.12     1.00       0.12   0.00
#>     monitoring     0.00  0.00     0.25       1.00   0.00
#>     effort         0.00  0.12     0.00       0.00   1.00
#> 
#>   Contemporaneous [directed]
#>     weights [0.125, 0.500]  |  +13 / -0 edges
#>                efficacy value planning monitoring effort
#>     efficacy       0.00  0.00     0.00       0.00   0.12
#>     value          0.38  0.00     0.38       0.12   0.50
#>     planning       0.38  0.00     0.00       0.00   0.50
#>     monitoring     0.25  0.12     0.25       0.00   0.00
#>     effort         0.12  0.00     0.25       0.38   0.00
#> 
#>   plot(x)  (faithful gimme-style mixed network) | plot(x, layer = "temporal") 
#>   edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)
```

No cross-variable path reaches the 75 percent group threshold. The five
autoregressive paths are fixed by `ar = TRUE` and carried by all eight
students; all selected cross-variable paths are individual-level. This
is a result of the stated rule and cutoffs, not a claim that the
population has no shared dynamics. The fitted temporal and
contemporaneous prevalence matrices range from 0.125 (one student) to
0.50 (four students) off the diagonal.

## Reading the output

The [`summary()`](https://rdrr.io/r/base/summary.html) method reports
one row per network layer, counting cross-variable edges only.

``` r

summary(gimme_fit)
#>           network n_nodes n_edges density mean_abs_weight n_positive n_negative
#> 1        temporal       5       8    0.40       0.1718750          8          0
#> 2 contemporaneous       5      13    0.65       0.2884615         13          0
```

The temporal layer holds eight cross-variable edges at density 0.40 and
mean prevalence 0.172; the contemporaneous layer holds 13 directed edges
at density 0.65 and mean prevalence 0.288. The
[`edges()`](https://mohsaqr.github.io/idiographic/reference/edges.md)
accessor lists every retained path with its layer, prevalence, and
level.

``` r

edges(gimme_fit)
#>            network       from         to weight      level
#> 1         temporal   efficacy   efficacy  1.000      group
#> 2         temporal      value      value  1.000      group
#> 3         temporal   planning   planning  1.000      group
#> 4         temporal monitoring monitoring  1.000      group
#> 5         temporal     effort     effort  1.000      group
#> 6  contemporaneous      value     effort  0.500 individual
#> 7  contemporaneous   planning     effort  0.500 individual
#> 8  contemporaneous      value   efficacy  0.375 individual
#> 9  contemporaneous      value   planning  0.375 individual
#> 10 contemporaneous   planning   efficacy  0.375 individual
#> 11 contemporaneous     effort monitoring  0.375 individual
#> 12        temporal   efficacy   planning  0.250 individual
#> 13        temporal      value   efficacy  0.250 individual
#> 14        temporal monitoring   planning  0.250 individual
#> 15 contemporaneous monitoring   efficacy  0.250 individual
#> 16 contemporaneous monitoring   planning  0.250 individual
#> 17 contemporaneous     effort   planning  0.250 individual
#> 18        temporal   efficacy monitoring  0.125 individual
#> 19        temporal      value     effort  0.125 individual
#> 20        temporal   planning      value  0.125 individual
#> 21        temporal   planning monitoring  0.125 individual
#> 22        temporal     effort      value  0.125 individual
#> 23 contemporaneous   efficacy     effort  0.125 individual
#> 24 contemporaneous      value monitoring  0.125 individual
#> 25 contemporaneous monitoring      value  0.125 individual
#> 26 contemporaneous     effort   efficacy  0.125 individual
```

The first five temporal rows are the fixed autoregressive self paths at
prevalence 1. Every cross-variable row is individual-level. The most
prevalent contemporaneous paths are value to effort and planning to
effort, each present in four of eight students; the most prevalent
cross-lagged paths occur in two of eight students.

``` r

head(coefs(gimme_fit))
#>   subject  network       from         to  weight
#> 1    Cira temporal   efficacy   efficacy  0.0689
#> 2    Cira temporal   efficacy   planning  0.2322
#> 3    Cira temporal      value      value  0.0809
#> 4    Cira temporal   planning   planning  0.6277
#> 5    Cira temporal monitoring   planning -0.2309
#> 6    Cira temporal monitoring monitoring  0.2347
nodes(gimme_fit)
#>            network       node strength out_strength in_strength self
#> 1         temporal   efficacy    0.625        0.375       0.250    1
#> 2         temporal      value    0.625        0.375       0.250    1
#> 3         temporal   planning    0.750        0.250       0.500    1
#> 4         temporal monitoring    0.500        0.250       0.250    1
#> 5         temporal     effort    0.250        0.125       0.125    1
#> 6  contemporaneous   efficacy    1.250        0.125       1.125    0
#> 7  contemporaneous      value    1.500        1.375       0.125    0
#> 8  contemporaneous   planning    1.750        0.875       0.875    0
#> 9  contemporaneous monitoring    1.125        0.625       0.500    0
#> 10 contemporaneous     effort    1.875        0.750       1.125    0
```

[`coefs()`](https://mohsaqr.github.io/idiographic/reference/coefs.md)
supplies the person-specific estimates that the prevalence display
abstracts away: one row per subject, layer, and path. The displayed rows
begin with Cira and show why prevalence and coefficient magnitude are
separate quantities. The
[`nodes()`](https://mohsaqr.github.io/idiographic/reference/nodes.md)
table sums prevalence over incident edges. Effort is the most connected
contemporaneous node (strength 1.875), while planning is most connected
temporally (strength 0.750); the `self` column separately records
autoregressive prevalence 1 for every variable.

``` r

matrices(gimme_fit)
#> 
#> $temporal_counts
#>            efficacy value planning monitoring effort
#> efficacy          8     2        0          0      0
#> value             0     8        1          0      1
#> planning          2     0        8          2      0
#> monitoring        1     0        1          8      0
#> effort            0     1        0          0      8
#> 
#> $temporal_avg
#>            efficacy  value planning monitoring effort
#> efficacy      0.024  0.081    0.000      0.000  0.000
#> value         0.000  0.236    0.029      0.000 -0.025
#> planning     -0.006  0.000    0.225      0.000  0.000
#> monitoring    0.032  0.000   -0.039      0.236  0.000
#> effort        0.000 -0.035    0.000      0.000  0.141
#> 
#> $contemporaneous_counts
#>            efficacy value planning monitoring effort
#> efficacy          0     3        3          2      1
#> value             0     0        0          1      0
#> planning          0     3        0          2      2
#> monitoring        0     1        0          0      3
#> effort            1     4        4          0      0
#> 
#> $contemporaneous_avg
#>            efficacy value planning monitoring effort
#> efficacy      0.000 0.164    0.151      0.013  0.127
#> value         0.000 0.000    0.000      0.059  0.000
#> planning      0.000 0.184    0.000     -0.007  0.131
#> monitoring    0.000 0.052    0.000      0.000  0.140
#> effort       -0.126 0.241    0.165      0.000  0.000
#> 
#> $path_counts
#>            efficacylag valuelag planninglag monitoringlag effortlag efficacy
#> efficacy             8        2           0             0         0        0
#> value                0        8           1             0         1        0
#> planning             2        0           8             2         0        0
#> monitoring           1        0           1             8         0        0
#> effort               0        1           0             0         8        1
#>            value planning monitoring effort
#> efficacy       3        3          2      1
#> value          0        0          1      0
#> planning       3        0          2      2
#> monitoring     1        0          0      3
#> effort         4        4          0      0
#> 
#> $contemp_cov
#>            efficacy value planning monitoring effort
#> efficacy          0     0        0          0      0
#> value             0     0        0          0      0
#> planning          0     0        0          0      0
#> monitoring        0     0        0          0      0
#> effort            0     0        0          0      0
#> 
#> $contemp_cov_avg
#>            efficacy value planning monitoring effort
#> efficacy          0     0        0          0      0
#> value             0     0        0          0      0
#> planning          0     0        0          0      0
#> monitoring        0     0        0          0      0
#> effort            0     0        0          0      0
```

[`matrices()`](https://mohsaqr.github.io/idiographic/reference/matrices.md)
returns the count and sample-average coefficient matrices behind these
tables, with outcomes on the rows and predictors on the columns. The
temporal count matrix has 8 on its diagonal and at most 2 in an
off-diagonal cell; the contemporaneous count matrix reaches 4. The
average coefficient matrices put magnitude beside recurrence; for
example, the planning-to-effort contemporaneous path appears in four
students and averages 0.165 across all eight. A path can therefore be
common and weak, so prevalence and magnitude have to be read together,
and neither should be mistaken for a standardized effect size.

## Visualizing the network

Plotting the fit draws the mixed network in the convention of the
`gimme` package: a single panel over the five nodes in which dashed
edges are lag-one temporal paths, solid edges are contemporaneous paths,
black edges belong to the group model, grey edges are individual-level,
and edge width scales with the weight. Under the default
`weight = "prop"` the width is path prevalence.

``` r

plot(gimme_fit, weight = "prop")
```

![](gimme_files/figure-html/plot-prop-1.png)

The dashed black self-loops constitute the fixed group structure; the
grey arrows are individual-level paths, drawn in proportion to how many
students carry them.

``` r

plot(gimme_fit, weight = "coef")
```

![](gimme_files/figure-html/plot-coef-1.png)

Reweighting by `weight = "coef"` keeps the same graph but scales width
by the sample-average coefficient, so the display answers how large
rather than how common. This view must still be read beside the count
matrix because an average over all eight students can be small even when
the fitted coefficients among the students carrying a path are sizeable.

## References
