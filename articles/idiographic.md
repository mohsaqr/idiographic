# 1. idiographic

`idiographic` estimates person-specific and within-person networks from
intensive longitudinal data. The package separates three questions that
are often conflated: a single person’s lagged process, the average
within-person process in a panel, and between-person covariance in
stable individual differences. The vignettes are ordered as a
method-selection guide, starting with data auditing, then ordinary and
regularized VAR, multilevel and Bayesian extensions, SEM/GIMME search,
rolling networks, and clean-room design. The organizing principle is
idiographic inference: parameters estimated for one person or one
within-person process should not be read as interchangeable with
between-person associations.

## The modelling problem

Let $`y_{itj}`$ denote variable $`j`$ for person $`i`$ at occasion
$`t`$. The central target is the conditional relation among variables
within a person’s ordered series. A temporal edge `from -> to` means
`from` at $`t-1`$ predicts `to` at $`t`$, holding the other lagged
variables constant. A contemporaneous edge is an undirected partial
correlation: the within-occasion association left after lagged
predictors and the remaining variables are conditioned out ([Bringmann
et al. 2013](#ref-bringmann2013); [Epskamp et al.
2018](#ref-epskamp2018mlvar)).

Single-subject VAR and graphical VAR estimate one parameter set for one
person. Subject-network estimators repeat that single-person analysis
for every person. Multilevel VAR and Bayesian DSEM estimate an average
within-person dynamic system, optionally adding random effects or a
between-person network. uSEM and GIMME treat the same lagged and
contemporaneous relations as structural paths, with GIMME adding a
group-search rule for paths shared by many people.

## Method selection

Ordinary VAR is the transparent baseline when one person has many
occasions relative to the number of variables. Graphical VAR is
preferable when sparsity is substantively defensible or the number of
candidate edges is large, because EBIC-regularized LASSO and
graphical-lasso estimation shrink weak temporal and contemporaneous
edges to zero.

Subject networks are appropriate when heterogeneity is itself the
target. Multilevel VAR is appropriate when the target is an average
within-person process across people and the analyst accepts partial
pooling. Bayesian VAR and DSEM are appropriate when uncertainty
intervals and dynamic SEM formulations are central. The native Bayesian
examples are executed during vignette building; only the licensed
external Mplus call is shown without execution.

## Data and preprocessing

The package example is the `srl` data set: 36 students, 156 occasions
per student, and nine self-regulated-learning indicators. The method
vignettes use the same five-variable subset so that printed matrices
remain readable.

``` r

vars <- c("efficacy", "value", "planning", "monitoring", "effort")
```

The preprocessing audit constructs the same lag-one design used by the
estimators and reports stationarity risks, missingness, and retained
pairs.

``` r

audit <- preprocess(srl, vars = vars, id = "name", min_obs = 100)
audit
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

The audit retains 5548 lagged pairs from 5616 rows. It reports 10 trend
flags, one drift flag, no high-autoregression flags, no unit-root risk,
and no zero-variance variables. Those flags make stationarity an
explicit modelling assumption rather than a hidden preprocessing step.

## Worked selection example

A compact comparison of Grace’s ordinary and graphical VAR shows how the
package exposes model choice as a table rather than a narrative
judgement. Grace is used because the preceding five-variable
stationarity audit gives her no trend, high-autoregression, drift,
unit-root, or zero-variance flag.

``` r

cmp <- compare_idiographic(
  srl, vars = vars, id = "name",
  estimators = c("var", "graphical_var"),
  estimator_args = list(
    var = list(subject = "Grace", scale = TRUE),
    graphical_var = list(subject = "Grace", n_lambda = 8)
  )
)
as.data.frame(cmp)
#>          method         network n_nodes n_edges density mean_abs_weight
#> 1           var        temporal       5      20     1.0      0.07457677
#> 2           var contemporaneous       5      10     1.0      0.16039547
#> 3 graphical_var        temporal       5       0     0.0      0.00000000
#> 4 graphical_var contemporaneous       5       3     0.3      0.20679444
#>   n_positive n_negative n_self max_abs_weight
#> 1          9         11      5      0.1604470
#> 2          6          4      0      0.4667434
#> 3          0          0      0      0.0000000
#> 4          3          0      0      0.2514403
```

The OLS VAR has full temporal and contemporaneous density, with mean
absolute temporal weight 0.075 and contemporaneous weight 0.160. The
graphical VAR keeps no temporal edges and three contemporaneous edges,
reducing the contemporaneous density to 0.30. The choice is therefore
not about which model is more elaborate; it is whether Grace’s weak
lagged coefficients should be retained as estimates or treated as
regularization noise.

## Caveats

All methods require an explicit alignment between the scientific
estimand and the data-generating design. A single-person network is not
a population network, a multilevel fixed effect is not an individual
map, and a between-person edge is not a within-person mechanism.
Stationarity, equal spacing, and missingness assumptions should be
checked before model interpretation. Sparse estimators improve selection
stability but bias surviving weights downward; unregularized estimators
expose every coefficient but can overstate weak edges in small samples.

## References

Bringmann, Laura F., Nathalie Vissers, Marieke Wichers, et al. 2013. “A
Network Approach to Psychopathology: New Insights into Clinical
Longitudinal Data.” *PLoS ONE* 8 (4): e60188.

Epskamp, Sacha, Lourens J. Waldorp, René Mõttus, and Denny Borsboom.
2018. “The Gaussian Graphical Model in Cross-Sectional and Time-Series
Data.” *Multivariate Behavioral Research* 53 (4): 453–80.
