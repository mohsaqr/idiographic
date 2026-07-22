# 7. Unified SEM

Unified structural equation modelling (uSEM) specifies a person-specific
structural model for a single individual’s multivariate time series, in
which each variable at the current occasion is regressed simultaneously
on the lagged values of all variables — its own and the others’ — and on
the other variables measured at the same occasion. It is an idiographic
model, built on the premise that within-person dynamics need not match
the between-person structure of the group: every coefficient describes
how one person’s process unfolds around that person’s own means, not how
people differ from one another. Like the other lag-one estimators in
this package, it presumes weak stationarity — constant mean, variance,
and autocovariance across the observation window — linear lag-one
dynamics, and equally spaced occasions; to these it adds the
identification requirements of a structural model, since the
within-occasion paths must be estimable for each person, which
constrains how many paths can be entertained relative to the length of
the series.

The model yields three networks over the same variables. The temporal
network is directed and within-person: an edge `from -> to` states that
the person’s value of `from` at occasion $`t-1`$ predicts their value of
`to` at occasion $`t`$, holding the other lagged variables constant. The
contemporaneous network collects the within-occasion relations, and this
layer is what separates uSEM from VAR and graphical VAR: where those
models summarize same-occasion association as undirected partial
correlations among residuals, uSEM resolves each within-occasion
relation into a *directed* structural path, so an edge `from -> to`
asserts a same-occasion effect of `from` on `to` for that person. What
the directed paths leave unexplained is carried by the third layer, an
undirected residual-covariance network among the innovations. The
directed contemporaneous reading is warranted when theory or design
implies a within-occasion ordering among the indicators; where no
ordering is defensible, the undirected graphical-VAR contemporaneous
network is the more conservative summary. GIMME, treated in the next
vignette, extends the uSEM equation with a group-level search that
recovers paths shared across people.

[`fit_usem()`](https://mohsaqr.github.io/idiographic/reference/fit_usem.md)
estimates one SEM per person and averages the resulting matrices across
the converged fits, returning the averaged temporal, directed
contemporaneous, and residual-covariance networks. The averages
summarize a sample of individual processes; they do not assert that any
single person’s model matches the average. When some subject-level
models fail to converge — as can happen when the trimming search is
enabled or the lagged path set is restricted — the function reports how
many failed and averages over the rest.

## Data and preprocessing

The estimator takes the same long-format panel as the other estimators:
one row per person-occasion, an id column, and numeric time-varying
indicators ordered within person. The bundled `srl` data hold
self-regulated-learning indicators for 36 students measured over 156
occasions each; this vignette fits all 36 students on five indicators:
`efficacy`, `value`, `planning`, `monitoring`, and `effort`. Because
uSEM is a dynamic lag-one model that absorbs assumption violations
silently — a trending series inflates its lagged coefficients rather
than producing an error — the stationarity screen precedes the fit.

``` r

preprocess(srl, vars = vars, id = "name")
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
#>   preprocess(data = srl, vars = vars, id = "name", detrend = "auto")
```

The five indicators over 36 students give 5616 ordered rows, of which
5548 survive as complete current/lagged pairs: each student loses the
first occasion to the initial lag, and a few students lose a little more
to missing values. Ten of the 180 subject-series trip the linear-trend
flag and one a drift flag, while the high-autoregression, unit-root, and
zero-variance screens are clear. The trends are mild, and the panel is
fitted as it stands; the `detrend` options described in the
preprocessing vignette are the corrective when the flags carry more
weight.

## Fitting the model

The substantive arguments are `time` (orders occasions within `id`),
`temporal` (`"ar"` for autoregressions only, `"all"` for the full lagged
matrix), `contemporaneous` (`"none"` or `"all"` directed same-occasion
paths), and `trim` (an optional search that prunes non-significant
paths). Estimating the full lagged and directed contemporaneous path
sets converges for every student here. The SEM fit is not evaluated
during vignette building because convergence can differ across build
environments; the excerpts below were generated from the displayed call.

``` r

usem_fit <- fit_usem(srl, vars = vars, id = "name", time = "day",
                     temporal = "all", contemporaneous = "all")
usem_fit
```

All 36 subject-level SEMs converge, each on 155 usable occasions. The
print method reports the three networks. The averaged temporal weights
are small, ranging from $`-0.086`$ to $`0.105`$, while the directed
contemporaneous paths are an order of magnitude larger, ranging from
$`-0.684`$ to $`0.475`$, and the residual covariances lie within
$`\pm 0.033`$ — the directed same-occasion structure absorbs almost all
of the within-occasion association.

## Reading the output

The [`summary()`](https://rdrr.io/r/base/summary.html) method reports
one row per network layer, with the edge count, density, and mean
absolute weight.

``` r

summary(usem_fit)
```

The contemporaneous network carries the process: its mean absolute
weight of 0.248 dwarfs the temporal figure of 0.038, and the residual
covariances average 0.014 in absolute value, confirming that the
directed paths leave little within-occasion association unexplained.

``` r

edges(usem_fit, network = "temporal", n = 5)
```

Averaged across students, the lag-one effects are weak: monitoring
predicts a small rise in next-occasion task value (0.103), and planning
predicts a small drop in subsequent effort ($`-0.086`$). As in the VAR
analysis, the within-person carry-over from one occasion to the next is
modest.

``` r

edges(usem_fit, network = "contemporaneous", n = 5)
```

The directed contemporaneous network is where uSEM adds information. The
strongest path runs from effort to monitoring ($`-0.684`$): within an
occasion, higher effort regulation is associated with lower monitoring.
Value directs onto efficacy (0.475) and efficacy onto monitoring
(0.453). These are directional statements a graphical VAR could not
make; there the same couplings would appear only as undirected partial
correlations among innovations.

``` r

nodes(usem_fit)
```

Because the contemporaneous layer is directed,
[`nodes()`](https://mohsaqr.github.io/idiographic/reference/nodes.md)
separates outgoing from incoming weight. Monitoring is the most central
contemporaneous node (strength 2.114) and receives far more than it
sends (in-strength 1.528 against out-strength 0.586), while effort has
the largest out-strength (1.265): in the averaged same-occasion
structure, effort directs and monitoring receives. The full averaged
path and residual matrices, including every coefficient the edge tables
truncate, are available from
[`coefs()`](https://mohsaqr.github.io/idiographic/reference/coefs.md)
and
[`matrices()`](https://mohsaqr.github.io/idiographic/reference/matrices.md).

``` r

matrices(usem_fit)
```

## Visualizing the network

The lagged and within-occasion structures are drawn separately, because
a lag-one edge connects one occasion to the next while the
contemporaneous paths and the residual covariances both live within a
single occasion. The temporal panel draws the directed lag-one network,
with edge width scaled to absolute weight and colour encoding sign.

``` r

plot(usem_fit, layer = "temporal")
```

The temporal graph is diffuse, echoing the narrow lag-one weight range.
The within-occasion structure is itself a mixed network, and
`plot(usem_fit, mixed = TRUE)` draws it as a single graph: the directed
contemporaneous paths appear as curved arrows and the undirected
residual covariances as straight edges, so the structural directions and
the associations they leave unexplained are seen together.

``` r

plot(usem_fit, mixed = TRUE)
```

The heavy effort-to-monitoring arrow dominates the directed structure,
while the residual covariances that remain are small and undirected. The
direction of each arrow is only as credible as the within-occasion
ordering assumption behind it, which is the consideration that should
govern the choice between uSEM and the undirected graphical-VAR
contemporaneous summary.

## References
