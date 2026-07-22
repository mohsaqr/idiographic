# 6. Bayesian VAR and DSEM

[`fit_var_bayes()`](https://mohsaqr.github.io/idiographic/reference/fit_var_bayes.md)
estimates a single-person Bayesian vector autoregression of order one:
an idiographic model, fitted to one individual’s multivariate series, in
which each occasion’s measurements are predicted jointly by the values
of all variables one occasion earlier and by the associations that
remain among the variables within the same occasion. The estimands are
the same two within-person networks the ordinary VAR of
[`fit_var()`](https://mohsaqr.github.io/idiographic/reference/fit_var.md)
returns. The temporal network is directed: an edge `from -> to` states
that the value of `from` at occasion $`t-1`$ predicts the value of `to`
at occasion $`t`$, holding the other lagged variables constant. The
contemporaneous network is undirected: its edges are the partial
correlations among the innovations, the within-occasion associations
that lagged prediction does not account for. The Bayesian estimator
places priors on the lagged coefficients and the innovation covariance
and reports posterior distributions over these same quantities, so each
edge carries a credible interval rather than a point estimate alone. The
model presumes weak stationarity — constant mean, variance, and
autocovariance across the observation window — linear lag-one dynamics,
approximately Gaussian fluctuations, and equally spaced measurement
occasions.

[`fit_mlvar_bayes()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar_bayes.md)
and
[`fit_mlvar_mplus()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar_mplus.md)
estimate the multilevel analogue, the Bayesian multilevel VAR in its
dynamic structural equation modelling (DSEM) formulation. Where the
single-person model describes one individual, the multilevel model pools
a panel of individuals and separates the variance into layers: a
population-level average within-person temporal network, a
population-level average within-person contemporaneous network, and a
between-person network — a partial-correlation network over the subject
means, describing how people who are high on one variable on average
tend to differ on the others. The between layer is a structure of stable
individual differences, not a within-person process, and the two need
not coincide; treating between-person associations as if they described
anyone’s dynamics is the ergodicity error the idiographic literature
warns against.
[`fit_mlvar_mplus()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar_mplus.md)
targets the Mplus DSEM backend for laboratories with a licensed Mplus
installation that require its syntax and diagnostics;
[`fit_mlvar_bayes()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar_bayes.md)
estimates a native model whose explicitly documented slices are
validated against frozen Mplus outputs without requiring the external
dependency.

Bayesian estimation is appropriate when posterior intervals, prior
regularization, or DSEM-style modelling is central to the analysis; when
the goal is a fast point-estimate comparison,
[`fit_var()`](https://mohsaqr.github.io/idiographic/reference/fit_var.md)
and
[`fit_mlvar()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar.md)
provide that baseline. The estimator chunks in this vignette are not
evaluated, because MCMC chains and external Mplus runs are inappropriate
for a fast package build; the printed excerpts below were generated from
the documented calls with short local chains and are reproduced as
static text.

## Data and preprocessing

The estimators expect long format: one row per person-occasion, an id
column, and numeric time-varying indicators ordered within person. The
bundled `srl` data hold self-regulated-learning indicators for 36
students measured over 156 occasions each. The single-person calls fit
one student, Grace, on five indicators; the multilevel calls use the
full panel of 36 students on the same variables. Because the estimators
absorb assumption violations silently — a trend, for instance, inflates
the autoregressive diagonal rather than producing an error — the
stationarity screen precedes the fit.

``` r

vars <- c("efficacy", "value", "planning", "monitoring", "effort")
preprocess(srl, vars = vars, id = "name", subject = "Grace")
#> Idiographic Preprocessing
#>   Variables:      5 (efficacy, value, planning, monitoring, effort)
#>   Ordered rows:   156
#>   Retained pairs: 155
#>   Trend flags:    0
#>   High AR flags:  0
#>   Drift flags:    0
#>   Unit-root risk: 0
#>   Zero variance:  0
#>   Tables:         x$pairs | x$counts | x$diagnostics
```

Grace’s 156 ordered occasions yield 155 complete current/lagged pairs,
and no series trips a trend, high-autoregression, drift, unit-root, or
zero-variance flag, so the models are specified on the series as they
stand.

## Fitting the model

The single-person call takes the data, the variable set, the id column,
and the subject; `n_iter` sets the chain length, `n_chains` the number
of chains, and `seed` fixes the random state for reproducibility.

``` r

var_bayes_fit <- fit_var_bayes(
  srl, vars = vars, id = "name", subject = "Grace",
  n_iter = 4000, n_chains = 2, seed = 1
)
var_bayes_fit
```

Precomputed excerpt from a short diagnostic run (`n_iter = 400`,
`n_chains = 1`):

``` text
Bayesian VAR(1) result (unregularized, Mplus-targeted)
  Variables:    5 (efficacy, value, planning, monitoring, effort)
  Observations: 155
  MCMC: 1 chains x 400 iter, 200 draws | max PSR = NA
  Temporal 95% CIs excluding 0: 1 / 25
  Temporal weights [-0.163, 0.162]
  Contemporaneous weights [-0.063, 0.468]
```

The multilevel Bayesian call uses the same panel structure as
[`fit_mlvar()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar.md).
Setting `temporal = "fixed"` estimates the average lag-one matrix
without subject-specific random deviations; `n_iter`, `n_chains`, and
`seed` control the MCMC as before.

``` r

mlvar_bayes_fit <- fit_mlvar_bayes(
  srl, vars = vars, id = "name", temporal = "fixed",
  n_iter = 4000, n_chains = 2, seed = 1
)
mlvar_bayes_fit
```

Precomputed excerpt from a short diagnostic run (`n_iter = 400`,
`n_chains = 1`):

``` text
Bayesian mlVAR (Mplus DSEM-targeted, temporal = fixed):
  36 subjects, 5548 observations, 5 variables
  Temporal 95% CIs excluding 0: 3 / 25
  Temporal weights [-0.041, 0.049]
  Contemporaneous weights [0.027, 0.272]
  Between weights [-0.073, 0.539]
```

The Mplus backend call is shown but not evaluated, because it requires
the suggested `mlVAR` and `MplusAutomation` packages plus a licensed
Mplus installation discoverable by
[`MplusAutomation::detectMplus()`](https://michaelhallquist.github.io/MplusAutomation/reference/detectMplus.html).

``` r

mplus_fit <- fit_mlvar_mplus(
  srl, vars = vars, id = "name",
  temporal = "fixed", contemporaneous = "fixed"
)
```

## Reading the output

The single-person posterior medians reproduce the ordinary VAR pattern.
Monitoring at occasion $`t-1`$ predicts lower value at occasion $`t`$
(posterior median −0.163), planning predicts higher effort (0.162), and
the largest contemporaneous edge is monitoring–effort (0.468). The same
accessors that serve the point-estimate fits apply:
[`summary()`](https://rdrr.io/r/base/summary.html) reports one row per
network layer,
[`edges()`](https://mohsaqr.github.io/idiographic/reference/edges.md)
lists edges in decreasing magnitude,
[`nodes()`](https://mohsaqr.github.io/idiographic/reference/nodes.md)
gives node-level strength, and
[`matrices()`](https://mohsaqr.github.io/idiographic/reference/matrices.md)
returns the underlying posterior-median matrices.

``` r

summary(var_bayes_fit)
edges(var_bayes_fit, n = 12)
nodes(var_bayes_fit)
matrices(var_bayes_fit)
```

The Bayesian mlVAR short run gives a temporal mean absolute weight of
0.012, a contemporaneous mean absolute weight of 0.165, and a
between-person mean absolute weight of 0.208 — the ordering typical of
multilevel panels, in which average lag-one effects are weak,
within-occasion structure is stronger, and the between layer is stronger
still. Monitoring at occasion $`t-1`$ to effort at occasion $`t`$ is the
largest average temporal edge (posterior median 0.031). Planning–effort
is the largest contemporaneous edge (0.272), and efficacy–planning is
the largest between-person edge (0.539) — a statement about which
students report high efficacy and high planning on average, not about
either process unfolding within any student.

``` r

summary(mlvar_bayes_fit)
edges(mlvar_bayes_fit, n = 12)
nodes(mlvar_bayes_fit)
matrices(mlvar_bayes_fit)
```

The [`plot()`](https://rdrr.io/r/graphics/plot.default.html) method
draws the layers with the same conventions as the other estimators:
arrows for lag-one prediction in the temporal panel, undirected edges
for the contemporaneous and between layers, width scaled by absolute
weight and colour encoding sign.

``` r

plot(var_bayes_fit)
plot(var_bayes_fit, layer = "temporal")
plot(var_bayes_fit, layer = "contemporaneous")
```

``` r

plot(mlvar_bayes_fit)
plot(mlvar_bayes_fit, layer = "temporal")
plot(mlvar_bayes_fit, layer = "contemporaneous")
plot(mlvar_bayes_fit, layer = "between")
```

The excerpts above are not a substitute for full MCMC practice. The
short chains were run only to anchor the vignette prose in real printed
values; applied analyses require adequate iterations, multiple chains,
convergence diagnostics such as the potential scale reduction factor,
posterior predictive checks, and sensitivity analyses over the priors.
[`fit_mlvar_mplus()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar_mplus.md)
additionally depends on an external Mplus installation, so it is
demonstrated only as a call template.

## References
