# Build a Multilevel Vector Autoregression (mlVAR) network

Estimates three networks from ESM/EMA panel data, matching
[`mlVAR::mlVAR()`](https://rdrr.io/pkg/mlVAR/man/mlVAR.html) with
`estimator = "lmer"`, `temporal = "fixed"`, `contemporaneous = "fixed"`
at machine precision: (1) a directed temporal network of fixed-effect
lagged regression coefficients, (2) an undirected contemporaneous
network of partial correlations among residuals, and (3) an undirected
between-subjects network of partial correlations derived from the
person-mean fixed effects.

## Usage

``` r
build_mlvar(
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
  subject = NULL
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

  Integer. Lag order; only `1` is supported (mlVAR's `lags`).

- estimator:

  Character. Only `"lmer"` / `"default"` are implemented; `"lm"` /
  `"Mplus"` raise an error (use
  [`mlVAR::mlVAR()`](https://rdrr.io/pkg/mlVAR/man/mlVAR.html)).

- temporal, contemporaneous:

  Character. Only `"fixed"` is implemented (idiographic is a clean-room
  of mlVAR's fixed-effects path). The random-effects modes
  (`"correlated"`, `"orthogonal"`, `"unique"`) raise an error pointing
  to [`mlVAR::mlVAR()`](https://rdrr.io/pkg/mlVAR/man/mlVAR.html).

- AR:

  Logical. If `TRUE`, estimate only autoregressive (own-lag) temporal
  effects, giving a diagonal temporal matrix (matches
  `mlVAR(AR = TRUE)`). Default `FALSE`.

- scale:

  Logical. If `TRUE`, each variable is grand-mean centered and divided
  by its pooled SD before augmentation (mlVAR's `scale`). Default
  `FALSE`. (The deprecated `standardize` is an alias.)

- scaleWithin:

  Logical. If `TRUE`, additionally scale within person (mlVAR's
  `scaleWithin`). Default `FALSE`.

- nCores:

  Integer. Accepted for API parity; estimation is single-threaded (a
  message is emitted if `nCores > 1`).

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

## Value

A dual-class `c("net_mlvar", "netobject_group")` object — a named list
of three full netobjects, one per network, plus model-level metadata
stored as attributes. Each element is a standard
`c("netobject", "cograph_network")` weight-matrix wrapper (no raw
`$data`), so [`print()`](https://rdrr.io/r/base/print.html),
[`summary()`](https://rdrr.io/r/base/summary.html),
[`coefs()`](https://saqr.me/idiographic/reference/coefs.md), and
`cograph::splot(fit$temporal)` work directly. The three constituents are
matrix-wrapped and carry no underlying panel data, so any
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
  [`coefs()`](https://saqr.me/idiographic/reference/coefs.md):

  Tidy `data.frame` with one row per `(outcome, predictor)` pair and
  columns `outcome`, `predictor`, `beta`, `se`, `t`, `p`, `ci_lower`,
  `ci_upper`, `significant`. Filter, sort, or plot with base R or the
  tidyverse. Retrieve with `coefs(fit)`.

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

Validated to machine precision (max_diff \< 1e-10) against
[`mlVAR::mlVAR()`](https://rdrr.io/pkg/mlVAR/man/mlVAR.html) on 25 real
ESM datasets from `openesm` and 20 simulated configurations (seeds
201-220). See `tmp/mlvar_equivalence_real20.R` and
`tmp/mlvar_equivalence_20seeds.R`.

## See also

[`build_gimme()`](https://saqr.me/idiographic/reference/build_gimme.md),
[`graphical_var()`](https://saqr.me/idiographic/reference/graphical_var.md),
[`as_netobject()`](https://saqr.me/idiographic/reference/as_netobject.md)

## Examples

``` r
# \donttest{
set.seed(1)
n_id <- 8; n_t <- 30; vars <- c("A", "B", "C")
rows <- lapply(seq_len(n_id), function(i) {
  m <- as.data.frame(matrix(rnorm(n_t * 3), ncol = 3))
  names(m) <- vars
  m$id <- i; m$day <- 1L; m$beep <- seq_len(n_t)
  m
})
d <- do.call(rbind, rows)
fit <- build_mlvar(d, vars = vars, id = "id", day = "day", beep = "beep")
#> Warning: Model for 'A': singular fit (random-effects variance near zero).
#> Warning: Model for 'A': boundary (singular) fit: see help('isSingular')
#> Warning: Model for 'B': singular fit (random-effects variance near zero).
#> Warning: Model for 'B': boundary (singular) fit: see help('isSingular')
#> Warning: Model for 'C': singular fit (random-effects variance near zero).
#> Warning: Model for 'C': boundary (singular) fit: see help('isSingular')
#> Warning: Between-subjects network not estimable: a random-intercept SD is 0 (no between-person variance). Returning a zero matrix by convention (mlVAR returns NA here).
print(fit)
#> mlVAR result: 8 subjects, 232 observations, 3 variables (lag 1)
#>   Temporal edges significant at p<0.05: 1 / 9
#> 
#>   Temporal [directed]
#>     weights [-0.131, 0.062]  |  +3 / -6 edges
#>           A     B     C
#>     A -0.13 -0.05 -0.03
#>     B -0.01 -0.08 -0.01
#>     C  0.06  0.02  0.04
#> 
#>   Contemporaneous [undirected]
#>     weights [0.006, 0.085]  |  +3 / -0 edges
#>          A    B    C
#>     A 0.00 0.06 0.08
#>     B 0.06 0.00 0.01
#>     C 0.08 0.01 0.00
#> 
#>   Between [undirected]
#>     no non-zero edges
#>       A B C
#>     A 0 0 0
#>     B 0 0 0
#>     C 0 0 0
#> 
#>   plot(x) | plot(x, layer = "temporal") | plot(x, layer = "between") 
#>   edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)
summary(fit)
#>           network n_nodes n_edges density mean_abs_weight n_positive n_negative
#> 1        temporal       3       6       1      0.03140474          2          4
#> 2 contemporaneous       3       3       1      0.05004674          3          0
#> 3         between       3       0       0      0.00000000          0          0
# }
```
