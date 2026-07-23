# Build a Bayesian VAR(1) network (unregularized, Mplus-targeted)

Native, pure-R Bayesian VAR(1) that reproduces Mplus's Bayesian
(DSEM/time-series) estimates without needing Mplus. It is the
unregularized Bayesian counterpart of
[`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md):
instead of a graphical-lasso / EBIC sparse fit, it estimates a full
VAR(1) with a flat prior on the temporal coefficients and an
inverse-Wishart prior on the residual precision, then reports the
temporal network `B` and the contemporaneous partial-correlation network
derived from the residual covariance. With more than one subject the
data are within-person centred and pooled (as in
[`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md)).

## Usage

``` r
fit_var_bayes(
  data,
  vars,
  id = NULL,
  day = NULL,
  beep = NULL,
  lags = 1L,
  scale = TRUE,
  center_within = TRUE,
  n_iter = 4000L,
  n_burnin = NULL,
  n_chains = 2L,
  thin = 1L,
  seed = NULL,
  min_obs = NULL,
  subject = NULL,
  verbose = FALSE
)
```

## Arguments

- data:

  A `data.frame` or matrix.

- vars:

  Character vector of variable names (length \>= 2).

- id:

  Character. Person-ID column, or `NULL` for a single series.

- day:

  Character. Day/session column, or `NULL`.

- beep:

  Character. Beep/measurement column, or `NULL`.

- lags:

  Integer lag order; only `1` is supported.

- scale:

  Logical. Global standardization of each variable. Default `TRUE`.

- center_within:

  Logical. Within-person centre when \>1 id (removes between-person
  variance, as in
  [`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md)).
  Default `TRUE`.

- n_iter, n_burnin, n_chains, thin:

  MCMC controls. Defaults `4000`, `n_iter/2`, `2`, `1`.

- seed:

  Integer or `NULL`. Base seed (chain `c` uses `seed + c`).

- min_obs:

  Integer or `NULL`. Keep only subjects with at least this many
  observations.

- subject:

  Optional vector naming the exact subject(s) to analyse.

- verbose:

  Logical. Progress messages. Default `FALSE`.

## Value

A `var_bayes_result` object (a cograph group with `temporal` and
`contemporaneous` netobjects) carrying `beta`, `temporal`, `kappa`,
`PCC`, `PDC`, posterior draws, and a tidy
[`coefs()`](https://mohsaqr.github.io/idiographic/reference/coefs.md)
table (posterior median, SD, 95% CI, one-tailed p, significance by CI
excluding 0).

## See also

[`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md)
(regularized GLASSO/EBIC),
[`fit_var()`](https://mohsaqr.github.io/idiographic/reference/fit_var.md)
(OLS),
[`fit_mlvar_bayes()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar_bayes.md)
(multilevel Bayesian VAR).

## Examples

``` r
# \donttest{
set.seed(1)
y <- matrix(0, 200, 2)
for (t in 2:200) y[t, ] <- c(0.4, 0.3) * y[t - 1, ] + rnorm(2)
d <- data.frame(A = y[, 1], B = y[, 2])
fit <- fit_var_bayes(d, vars = c("A", "B"), n_iter = 500, seed = 1)
print(fit)
#> Bayesian VAR(1) result (unregularized, Mplus-targeted)
#>   Variables:    2 (A, B)
#>   Observations: 199
#>   MCMC: 2 chains x 500 iter, 500 draws | max PSR = 1.010
#>   Temporal 95% CIs excluding 0: 2 / 4
#> 
#>   Temporal [directed]
#>     weights [-0.057, 0.426]  |  +2 / -2 edges
#>           A     B
#>     A  0.43 -0.05
#>     B -0.06  0.26
#> 
#>   Contemporaneous [undirected]
#>     weights [-0.012, -0.012]  |  +0 / -1 edges
#>           A     B
#>     A  0.00 -0.01
#>     B -0.01  0.00
#> 
#>   coefs(x) | matrices(x) | edges(x) | nodes(x) | summary(x)
coefs(fit)
#>   outcome predictor    estimate posterior_sd   ci_lower   ci_upper     p
#> 1       A         A  0.42622237   0.06617353  0.3038259 0.55781645 0.000
#> 2       A         B -0.05725438   0.06822709 -0.1831618 0.08338037 0.194
#> 3       B         A -0.05098612   0.07220854 -0.1865525 0.09368754 0.240
#> 4       B         B  0.26411833   0.06976118  0.1318581 0.40487278 0.000
#>   significant
#> 1        TRUE
#> 2       FALSE
#> 3       FALSE
#> 4        TRUE
# }
```
