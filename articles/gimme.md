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
bundled `srl` data hold self-regulated-learning indicators for 36
students measured over 156 occasions each; `name` identifies the student
and `day` orders the occasions. Five indicators enter the model:
`efficacy`, `value`, `planning`, `monitoring`, and `effort`. Because
GIMME estimates a full SEM per subject, each individual series must
carry the model on its own, so the screen below also requires at least
100 usable occasions per student.

``` r

vars <- c("efficacy", "value", "planning", "monitoring", "effort")
preprocess(srl, vars = vars, id = "name", min_obs = 100)
#> Idiographic Preprocessing
#>   Variables:      5 (efficacy, value, planning, monitoring, effort)
#>   Ordered rows:   5616
#>   Retained pairs: 5548
#>   Trend flags:    10
#>   High AR flags:  0
#>   Drift flags:    1
#>   Unit-root risk: 0
#>   Zero variance:  0
#>   Tables:         x$pairs | x$counts | x$diagnostics
#> 
#> 10 of 180 subject-series show a trend or unit-root that can bias the temporal network. preprocess() only diagnosed this; to clean just the series that need it, re-run with:
#>   preprocess(data = srl, vars = vars, id = "name", min_obs = 100, detrend = "auto")
```

The 36 students supply 5616 ordered rows, of which 5548 survive as
complete current/lagged pairs. Ten of the 180 subject-series trip the
linear-trend flag and one shows drift; none shows high autoregression,
unit-root risk, or zero variance. The fitted example uses eight students
to keep the vignette fast while preserving the `srl` measurement design.

## Fitting the model

The estimator takes the data, the variable set, the id column, and the
time column; `time = "day"` orders occasions within each student.
`ar = TRUE` places an autoregressive path on every variable in every
subject’s model from the outset, which anchors the search.
`groupcutoff = 0.75` and `subcutoff = 0.75` require a path to improve
fit in at least 75 percent of the relevant subjects — here, six of the
eight — before it is promoted by the corresponding rule.

``` r

vars <- c("efficacy", "value", "planning", "monitoring", "effort")
students <- subset(srl, name %in% c("Grace", "Eve", "Aisha", "Alice",
                                    "Bob", "Diana", "Frank", "Heidi"))
gimme_fit <- fit_gimme(
  students, vars = vars, id = "name", time = "day",
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
#> Group-level paths found: 2 
#>    effort~planning 
#>    monitoring~efficacy 
#> 
#> Individual-level paths:  mean 3.2, range 2-5
#> 
#> Proportion of subjects with each path:
#> 
#>   Temporal [directed]
#>     weights [0.125, 1.000]  |  +6 / -0 edges
#>                efficacy value planning monitoring effort
#>     efficacy          1     0        0          0   0.00
#>     value             0     1        0          0   0.00
#>     planning          0     0        1          0   0.12
#>     monitoring        0     0        0          1   0.00
#>     effort            0     0        0          0   1.00
#> 
#>   Contemporaneous [directed]
#>     weights [0.125, 1.000]  |  +15 / -0 edges
#>                efficacy value planning monitoring effort
#>     efficacy       0.00  0.25     0.50       1.00   0.25
#>     value          0.25  0.00     0.25       0.00   0.00
#>     planning       0.12  0.00     0.00       0.25   1.00
#>     monitoring     0.00  0.38     0.00       0.00   0.12
#>     effort         0.12  0.25     0.12       0.25   0.00
#> 
#>   plot(x)  (faithful gimme-style mixed network) | plot(x, layer = "temporal") 
#>   edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)
```

The group model contains the five autoregressive paths, fixed by
`ar = TRUE` and carried by all eight students, plus the two
contemporaneous paths the group search added: efficacy predicting
monitoring and planning predicting effort, each present in every
student’s model. No cross-variable temporal path met the group
criterion, so the shared lag-one structure is autoregressive only — a
statement about replication at these cutoffs, not about the absence of
lagged effects in any one student. The individual-level search then
added between one and four further contemporaneous paths per student,
2.5 on average. The printed matrices hold prevalences: the temporal
matrix has 1 on its diagonal and 0 elsewhere, and the contemporaneous
matrix runs from 0.125 — a path carried by a single student — up to 1
for the two group paths.

## Reading the output

The [`summary()`](https://rdrr.io/r/base/summary.html) method reports
one row per network layer, counting cross-variable edges only.

``` r

summary(gimme_fit)
#>           network n_nodes n_edges density mean_abs_weight n_positive n_negative
#> 1        temporal       5       1    0.05       0.1250000          1          0
#> 2 contemporaneous       5      15    0.75       0.3416667         15          0
```

The temporal layer shows zero edges and density 0, because its only
retained paths are the self-loops, which are tallied separately. The
contemporaneous layer holds 13 directed edges at density 0.65 — 13 of
the 20 possible ordered pairs — with a mean prevalence of 0.346 across
retained paths. The
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
#> 6  contemporaneous   efficacy monitoring  1.000      group
#> 7  contemporaneous   planning     effort  1.000      group
#> 8  contemporaneous   efficacy   planning  0.500 individual
#> 9  contemporaneous monitoring      value  0.375 individual
#> 10 contemporaneous   efficacy      value  0.250 individual
#> 11 contemporaneous   efficacy     effort  0.250 individual
#> 12 contemporaneous      value   efficacy  0.250 individual
#> 13 contemporaneous      value   planning  0.250 individual
#> 14 contemporaneous   planning monitoring  0.250 individual
#> 15 contemporaneous     effort      value  0.250 individual
#> 16 contemporaneous     effort monitoring  0.250 individual
#> 17        temporal   planning     effort  0.125 individual
#> 18 contemporaneous   planning   efficacy  0.125 individual
#> 19 contemporaneous monitoring     effort  0.125 individual
#> 20 contemporaneous     effort   efficacy  0.125 individual
#> 21 contemporaneous     effort   planning  0.125 individual
```

The five temporal rows are the autoregressive self paths at prevalence
1, labelled group. The contemporaneous rows split by level: the two
group paths at prevalence 1, then eleven individual-level paths, from
efficacy predicting planning and monitoring predicting value at 0.375 —
three of the eight students — down to four paths carried by a single
student at 0.125.

``` r

head(coefs(gimme_fit))
#>   subject         network       from         to  weight
#> 1   Aisha        temporal   efficacy   efficacy  0.1428
#> 2   Aisha        temporal      value      value  0.1150
#> 3   Aisha        temporal   planning   planning -0.0340
#> 4   Aisha        temporal monitoring monitoring -0.0009
#> 5   Aisha        temporal     effort     effort  0.1293
#> 6   Aisha contemporaneous   efficacy      value  0.4799
nodes(gimme_fit)
#>            network       node strength out_strength in_strength self
#> 1         temporal   efficacy    0.000        0.000       0.000    1
#> 2         temporal      value    0.000        0.000       0.000    1
#> 3         temporal   planning    0.125        0.125       0.000    1
#> 4         temporal monitoring    0.000        0.000       0.000    1
#> 5         temporal     effort    0.125        0.000       0.125    1
#> 6  contemporaneous   efficacy    2.500        2.000       0.500    0
#> 7  contemporaneous      value    1.375        0.500       0.875    0
#> 8  contemporaneous   planning    2.250        1.375       0.875    0
#> 9  contemporaneous monitoring    2.000        0.500       1.500    0
#> 10 contemporaneous     effort    2.125        0.750       1.375    0
```

[`coefs()`](https://mohsaqr.github.io/idiographic/reference/coefs.md)
supplies the person-specific estimates that the prevalence display
abstracts away: one row per subject, layer, and path, holding that
subject’s regression coefficient. The first rows belong to Aisha — her
five autoregressive coefficients, small values between −0.034 and 0.143,
and the first of her contemporaneous paths, efficacy predicting value at
0.48. The
[`nodes()`](https://mohsaqr.github.io/idiographic/reference/nodes.md)
table sums prevalence over the edges incident to each node within a
layer. Contemporaneously, efficacy is the most connected node (strength
2.125) and predominantly a sender (out-strength 1.875), while monitoring
and effort are the main receivers (in-strength 1.375 each) and value
participates least (strength 1.25). In the temporal layer the `self`
column records the autoregressive prevalence of 1 for every variable,
with no cross-variable strength.

``` r

matrices(gimme_fit)
#> 
#> $temporal_counts
#>            efficacy value planning monitoring effort
#> efficacy          8     0        0          0      0
#> value             0     8        0          0      0
#> planning          0     0        8          0      0
#> monitoring        0     0        0          8      0
#> effort            0     0        1          0      8
#> 
#> $temporal_avg
#>            efficacy value planning monitoring effort
#> efficacy     -0.005 0.000    0.000      0.000  0.000
#> value         0.000 0.045    0.000      0.000  0.000
#> planning      0.000 0.000    0.032      0.000  0.000
#> monitoring    0.000 0.000    0.000     -0.029  0.000
#> effort        0.000 0.000    0.026      0.000  0.011
#> 
#> $contemporaneous_counts
#>            efficacy value planning monitoring effort
#> efficacy          0     2        1          0      1
#> value             2     0        0          3      2
#> planning          4     2        0          0      1
#> monitoring        8     0        2          0      2
#> effort            2     0        8          1      0
#> 
#> $contemporaneous_avg
#>            efficacy value planning monitoring effort
#> efficacy      0.000 0.068    0.044      0.000  0.039
#> value         0.101 0.000    0.000      0.138  0.120
#> planning      0.240 0.121    0.000      0.000 -0.075
#> monitoring    0.316 0.000   -0.025      0.000 -0.028
#> effort        0.097 0.000    0.384      0.055  0.000
#> 
#> $path_counts
#>            efficacylag valuelag planninglag monitoringlag effortlag efficacy
#> efficacy             8        0           0             0         0        0
#> value                0        8           0             0         0        2
#> planning             0        0           8             0         0        4
#> monitoring           0        0           0             8         0        8
#> effort               0        0           1             0         8        2
#>            value planning monitoring effort
#> efficacy       2        1          0      1
#> value          0        0          3      2
#> planning       2        0          0      1
#> monitoring     0        2          0      2
#> effort         0        8          1      0
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
returns the count and group-average coefficient matrices behind these
tables, with outcomes on the rows and predictors on the columns. The
temporal count matrix has 8 on its diagonal and 0 elsewhere; the
contemporaneous count matrix reaches 8 only in the two group cells. The
average coefficient matrices put magnitudes on the shared structure:
across the eight students the efficacy-to-monitoring path averages 0.325
and the planning-to-effort path 0.361, while the mean autoregressive
coefficients lie between −0.027 and 0.045. A path can therefore be
universal and weak — at these cutoffs the shared temporal structure is
exactly that — so prevalence and magnitude have to be read together, and
neither should be mistaken for a standardized effect size.

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

The dashed black self-loops and the two solid black arrows — efficacy to
monitoring and planning to effort — constitute the group model; the grey
arrows are individual-level paths, drawn thinner in proportion to how
few students carry them.

``` r

plot(gimme_fit, weight = "coef")
```

![](gimme_files/figure-html/plot-coef-1.png)

Reweighting by `weight = "coef"` keeps the same graph but scales width
by the group-average coefficient, so the display answers how strong
rather than how common: the two group contemporaneous arrows dominate at
0.325 and 0.361, and the autoregressive loops recede because their
average coefficients fall below 0.05 in absolute value.

## References
