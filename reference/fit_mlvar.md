# Build a Multilevel Vector Autoregression (mlVAR) network

Estimates three networks from ESM/EMA panel data, matching validated
[`mlVAR::mlVAR()`](https://rdrr.io/pkg/mlVAR/man/mlVAR.html)
configurations at machine precision: (1) a directed temporal network of
fixed-effect lagged regression coefficients, (2) an undirected
contemporaneous network of partial correlations among residuals, and (3)
an undirected between-subjects network of partial correlations derived
from the person-mean fixed effects.

## Usage

``` r
fit_mlvar(
  data,
  vars,
  id,
  day = NULL,
  beep = NULL,
  lags = 1L,
  estimator = c("lmer", "default", "lm", "Mplus"),
  temporal = c("fixed", "correlated", "orthogonal", "unique", "default"),
  contemporaneous = c("fixed", "correlated", "orthogonal", "unique", "default"),
  AR = FALSE,
  scale = FALSE,
  scaleWithin = FALSE,
  nCores = 1L,
  verbose = FALSE,
  lag = NULL,
  standardize = NULL,
  min_obs = NULL,
  subject = NULL,
  engine = c("frequentist", "bayes", "mplus", "reference"),
  standardize_mode = NULL,
  missing = c("omit", "fail", "model"),
  compare_to_lags = NULL,
  true_means = NULL,
  detrend = c("none", "position"),
  na_rm = TRUE,
  orthogonal = NULL,
  ...
)
```

## Arguments

- data:

  A `data.frame` containing the panel data.

- vars:

  Character vector of variable column names to model.

- id:

  Character string naming the person-ID column.

- day:

  Character string naming the day/session column, or `NULL`. When
  provided, lag pairs are only formed within the same day.

- beep:

  Character string naming the measurement-occasion column, or `NULL`.
  When `NULL`, row position within each (id, day) is used.

- lags:

  One or more unique positive integer lag orders (mlVAR's `lags`).

- estimator:

  Character. Frequentist estimator: `"lmer"` (multilevel) or `"lm"`
  (separate person-specific models, requiring `temporal = "unique"`).
  The legacy value `"Mplus"` selects `engine = "mplus"`.

- temporal, contemporaneous:

  Character random-effect structure. The native frequentist engine
  supports fixed, correlated, orthogonal, and unique person-specific
  effects. The Bayesian engine maps correlated/orthogonal/ unique
  temporal effects to its full random-slope model.

- AR:

  Logical. If `TRUE`, estimate only autoregressive (own-lag) temporal
  effects, giving a diagonal temporal matrix (matches
  `mlVAR(AR = TRUE)`). For the native frequentist/reference path this
  requires `estimator = "lmer"`. Default `FALSE`.

- scale:

  Logical. If `TRUE`, each variable is grand-mean centred and divided by
  its pooled SD before augmentation (mlVAR's `scale`). Default `FALSE`.
  (The deprecated `standardize` is an alias.)

- scaleWithin:

  Logical. If `TRUE`, additionally scale within person (mlVAR's
  `scaleWithin`). Default `FALSE`.

- nCores:

  Positive integer number of outcome models to fit in parallel. Uses
  forked workers on Unix-like systems and a PSOCK cluster on Windows.

- verbose:

  Logical. Emit progress messages. Default `FALSE`.

- lag:

  Deprecated alias for `lags`.

- standardize:

  Deprecated alias for `scale`.

- min_obs:

  Integer or `NULL`. Keep only subjects with at least this many
  observations (counts taken from `data`).

- subject:

  Optional vector naming the exact subject(s) to analyse.

- engine:

  Estimation engine: `"frequentist"` (native lme4/base R), `"bayes"`
  (the native DSEM sampler), `"mplus"` (licensed Mplus through
  [`fit_mlvar_mplus()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar_mplus.md)),
  or `"reference"` (direct
  [`mlVAR::mlVAR()`](https://rdrr.io/pkg/mlVAR/man/mlVAR.html) followed
  by conversion to idiographic's tidy result contract).

- standardize_mode:

  Easy standardization vocabulary: `"none"`, `"global"`, `"within"`, or
  `"both"`. When supplied it sets `scale` and `scaleWithin`; the logical
  legacy arguments remain supported.

- missing:

  Missing-data policy: `"omit"`, `"fail"`, or `"model"`. `"fail"` checks
  model variables and ID/day/beep ordering keys. Within-model imputation
  is available with the Bayesian random-slope engine.

- compare_to_lags:

  Optional positive lag vector used only to align the analysis rows when
  comparing models with different lag orders. It must include every
  fitted value in `lags`; for example, use `c(1, 2)` while fitting lag 1
  for a comparison with a lag-2 model.

- true_means:

  Optional data frame containing `id` and all `vars`, used as known
  person means instead of sample means.

- detrend:

  `"none"` or `"position"`. Position detrending standardizes each
  measurement position across subjects before model standardization.

- na_rm:

  Logical legacy spelling for whether incomplete model rows are omitted.
  `FALSE` is equivalent to `missing = "fail"`.

- orthogonal:

  Deprecated upstream compatibility flag. When supplied it sets
  `temporal = "orthogonal"` (`TRUE`) or `"correlated"` (`FALSE`).

- ...:

  Engine-specific controls. For example `n_iter`, `n_chains`, and
  `residual` for the Bayesian engine, or Mplus controls for the Mplus
  engine.

## Value

A dual-class `c("net_mlvar", "netobject_group")` object — a named list
of three full netobjects, one per network, plus model-level metadata
stored as attributes. Each element is a standard
`c("netobject", "cograph_network")` weight-matrix wrapper (no raw
`$data`), so [`print()`](https://rdrr.io/r/base/print.html),
[`summary()`](https://rdrr.io/r/base/summary.html),
[`coefs()`](https://pak.dynasite.org/idiographic/reference/coefs.md),
[`edges()`](https://pak.dynasite.org/idiographic/reference/edges.md) and
`plot(fit, layer = "temporal")` work directly. The three constituents
are matrix-wrapped and carry no underlying panel data, so any
data-resampling workflow (bootstrap, reliability, stability) must start
from the original panel rather than from these wrappers. Structure:

- `fit$temporal`:

  Directed netobject for the `d x d` matrix of fixed-effect lagged
  coefficients. `$weights[i, j]` is the effect of variable j at t-lag on
  variable i at t. `method = "mlvar_temporal"`, `directed = TRUE`.

- `fit$contemporaneous`:

  Undirected netobject for the `d x d` partial-correlation network of
  within-person lmer residuals. `method = "mlvar_contemporaneous"`,
  `directed = FALSE`.

- `fit$between`:

  Undirected netobject for the `d x d` partial-correlation network of
  person means, derived from `D (I - Gamma)`.
  `method = "mlvar_between"`, `directed = FALSE`. **Convention:** when a
  random-intercept SD is 0 the between network is not estimable;
  idiographic returns an all-zero matrix (with a warning) as a
  plotting-oriented convention, whereas `mlVAR` returns an all-`NA`
  matrix. The contemporaneous network follows the same
  zero-on-degeneracy convention. This is a deliberate departure from
  strict reference equivalence in the singular case.

- `attr(fit, "coefs")` /
  [`coefs()`](https://pak.dynasite.org/idiographic/reference/coefs.md):

  Tidy `data.frame` with one row per `(outcome, predictor)` pair and
  columns `outcome`, `predictor`, `beta`, `se`, `t`, `p`, `ci_lower`,
  `ci_upper`, `significant`. Retrieve with `coefs(fit)`.

- `attr(fit, "n_obs")`:

  Number of rows in the augmented panel after na.omit.

- `attr(fit, "n_subjects")`:

  Number of unique subjects remaining.

- `attr(fit, "lag")`:

  Lag order used.

- `attr(fit, "standardize")`:

  Logical; whether pre-augmentation standardization was applied.

## Details

The algorithm follows mlVAR's lmer pipeline exactly:

1.  Drop rows with NA in id/day/beep and optionally grand-mean
    standardize each variable.

2.  Expand the per-(id, day) beep grid and right-join original values,
    producing the augmented panel (`augData`).

3.  Add within-person lagged predictors (`L1_*`) and person-mean
    predictors (`PM_*`).

4.  For each outcome variable fit
    `lmer(y ~ within + between-except-own-PM + (1 | id))` with
    `REML = FALSE`. Collect the fixed-effect temporal matrix `B`,
    between-effect matrix `Gamma`, random-intercept SDs (`mu_SD`), and
    lmer residual SDs.

5.  Contemporaneous network:
    `cor2pcor(D %*% cov2cor(cor(resid)) %*% D)`.

6.  Between-subjects network:
    `cor2pcor(pseudoinverse(forcePositive(D (I - Gamma))))`.

The committed oracle matrix validates fixed temporal/contemporaneous
`lmer` fits at lags 1 and 1+2, preprocessing controls (`scale`,
`scaleWithin`, `compareToLags`, `trueMeans`, and position detrending),
and lag-1 `estimator = "lm"`, `temporal = "unique"` fits across every
supported contemporaneous structure. Other configurations carry a
narrower declaration available through
[`equivalence()`](https://pak.dynasite.org/idiographic/reference/equivalence.md).

## Observation keys

When `beep` is supplied, every complete `(id, day, beep)` key (or
`(id, beep)` when `day = NULL`) must be unique. Duplicate keys often
indicate that a study-period/session column was lost during data
conversion. Because upstream join behaviour is row-order dependent in
that case, `fit_mlvar()` errors and asks you to resolve or explicitly
deduplicate the source data.

## See also

[`fit_gimme()`](https://pak.dynasite.org/idiographic/reference/fit_gimme.md),
[`fit_graphical_var()`](https://pak.dynasite.org/idiographic/reference/fit_graphical_var.md),
[`as_netobject()`](https://pak.dynasite.org/idiographic/reference/as_netobject.md)

## Examples

``` r
# \donttest{
# Temporal, contemporaneous and between-person networks of 36 learners.
fit <- fit_mlvar(srl, vars = c("efficacy", "planning", "effort"),
                 id = "name", beep = "day")
print(fit)
#> mlVAR result: 36 subjects, 5560 observations, 3 variables (lags 1)
#>   Temporal edges significant at p<0.05: 1 / 9
#> 
#>   Temporal [directed]
#>     weights [-0.043, 0.018]  |  +7 / -2 edges
#>              efficacy planning effort
#>     efficacy    -0.04     0.02   0.01
#>     planning     0.00     0.00  -0.01
#>     effort       0.01     0.01   0.02
#> 
#>   Contemporaneous [undirected]
#>     weights [0.276, 0.316]  |  +3 / -0 edges
#>              efficacy planning effort
#>     efficacy     0.00     0.31   0.28
#>     planning     0.31     0.00   0.32
#>     effort       0.28     0.32   0.00
#> 
#>   Between [undirected]
#>     weights [0.242, 0.576]  |  +3 / -0 edges
#>              efficacy planning effort
#>     efficacy     0.00     0.58   0.43
#>     planning     0.58     0.00   0.24
#>     effort       0.43     0.24   0.00
#> 
#>   plot(x) | plot(x, layer = "temporal") | plot(x, layer = "between") 
#>   edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)
summary(fit)
#>           network n_nodes n_edges density mean_abs_weight n_positive n_negative
#> 1        temporal       3       6       1      0.01030487          5          1
#> 2 contemporaneous       3       3       1      0.29905010          3          0
#> 3         between       3       3       1      0.41476433          3          0
coefs(fit)
#>    outcome predictor         beta         se           t           p
#> 1 efficacy  efficacy -0.043237380 0.01548000 -2.79311194 0.005220362
#> 2 efficacy  planning  0.002678248 0.01529428  0.17511435 0.860989785
#> 3 efficacy    effort  0.009946583 0.01478094  0.67293285 0.500990009
#> 4 planning  efficacy  0.018342219 0.01589811  1.15373559 0.248608586
#> 5 planning  planning  0.001165663 0.01570737  0.07421122 0.940842318
#> 6 planning    effort  0.007143440 0.01518017  0.47057699 0.637942841
#> 7   effort  efficacy  0.014571162 0.01627931  0.89507225 0.370748466
#> 8   effort  planning -0.009147594 0.01608400 -0.56873867 0.569533499
#> 9   effort    effort  0.017620258 0.01554416  1.13356133 0.256978601
#>      ci_lower    ci_upper significant
#> 1 -0.07357763 -0.01289713        TRUE
#> 2 -0.02729799  0.03265449       FALSE
#> 3 -0.01902354  0.03891670       FALSE
#> 4 -0.01281751  0.04950195       FALSE
#> 5 -0.02962022  0.03195155       FALSE
#> 6 -0.02260915  0.03689603       FALSE
#> 7 -0.01733571  0.04647803       FALSE
#> 8 -0.04067166  0.02237647       FALSE
#> 9 -0.01284573  0.04808625       FALSE
# }
```
