# Build a Bayesian multilevel VAR network (Mplus DSEM-targeted)

Native, pure-R Bayesian estimator for a two-level VAR(1) that
statistically reproduces Mplus DSEM output (the estimator behind
`mlVAR::mlVAR(estimator = "Mplus")`) without needing Mplus installed. A
conjugate Gibbs sampler estimates a fixed temporal matrix, a
within-person residual (contemporaneous) network, and a between-person
network, using latent mean centring and Mplus's default priors. Point
estimates are posterior medians with posterior SDs and 95% credible
intervals.

## Usage

``` r
fit_mlvar_bayes(
  data,
  vars,
  id,
  day = NULL,
  beep = NULL,
  lags = 1L,
  temporal = c("fixed", "default", "random"),
  contemporaneous = c("fixed", "default"),
  residual = c("fixed", "random"),
  scale = TRUE,
  scaleWithin = FALSE,
  tinterval = NULL,
  impute = FALSE,
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

  A `data.frame` containing the panel data.

- vars:

  Character vector of variable column names to model (length \>= 2).

- id:

  Character string naming the person-ID column.

- day:

  Character string naming the day/session column, or `NULL`.

- beep:

  Character string naming the measurement-occasion column, or `NULL`.
  When `NULL`, row position within each (id, day) block is used.

- lags:

  Integer lag order; only `1` is supported (matches Mplus DSEM defaults
  here).

- temporal:

  Character. `"fixed"` (default) fits fixed temporal effects with random
  intercepts (Mplus DSEM `temporal = "fixed"`). `"random"` fits the full
  DSEM with person-specific temporal matrices `B_i` and a full
  random-effect covariance over `(mu_i, vec(B_i))`; the temporal network
  then reports the posterior mean transition matrix and
  `attr(fit, "slope_sd")` holds the per-coefficient random-slope SDs.
  `"random"` needs more subjects estimable random-effect covariance: at
  least `2 * (p + p^2) + 1` subjects.

- contemporaneous:

  Character. Only `"fixed"` is implemented.

- residual:

  Character. `"fixed"` (default) uses one shared population
  within-person residual covariance. `"random"` (only with
  `temporal = "random"`) gives each subject their own residual
  covariance `Sigma_W_i` via a conjugate hierarchical inverse-Wishart
  (`Sigma_W_i ~ IW(Lambda, p + 2)`, `Lambda ~ Wishart`), matching DSEM
  person-specific innovation variances; the reported contemporaneous
  network is then the population-average residual covariance.

- scale:

  Logical. Global grand-mean/SD standardization of each variable before
  fitting (Mplus/`mlVAR` `scale = TRUE`). Default `TRUE`.

- scaleWithin:

  Logical. Additionally within-person scale each variable. Default
  `FALSE`.

- tinterval:

  Numeric or `NULL`. When supplied, `beep` is treated as a continuous
  time variable and binned onto a regular grid of this width (Mplus
  `TINTERVAL`); the integer bin becomes the occasion index for gap-aware
  lagging, and multiple observations in one (id, day, bin) slot are
  collapsed to the first. Lagging is gap-aware in all cases: lag-1 pairs
  are only formed between consecutive occasions, so missing occasions
  never create spurious lag pairs. Default `NULL`.

- impute:

  Logical. If `TRUE` (only with `temporal = "random"`), missing
  observations are imputed **within the model** each MCMC iteration
  (data augmentation), rather than dropped: each person's series is
  expanded to a full occasion grid and every latent cell is drawn from
  its Gaussian full conditional (as an outcome at `t` and a predictor at
  `t+1`), using a vectorised even/odd (checkerboard) block sweep. This
  matches how Mplus / Stan / JAGS handle missing data and removes the
  listwise-deletion bias under heavy missingness, at extra computational
  cost. Default `FALSE`.

- n_iter:

  Integer. Total MCMC iterations per chain. Default `4000`.

- n_burnin:

  Integer. Burn-in iterations discarded per chain. Default `n_iter / 2`
  (Mplus's first-half burn-in convention).

- n_chains:

  Integer. Number of independent chains. Default `2`.

- thin:

  Integer. Keep every `thin`-th post-burn-in draw. Default `1`.

- seed:

  Integer or `NULL`. Base RNG seed (chain `c` uses `seed + c`).

- min_obs:

  Integer or `NULL`. Keep only subjects with at least this many
  observations before fitting.

- subject:

  Optional vector naming the exact subject(s) to analyse.

- verbose:

  Logical. Emit progress messages. Default `FALSE`.

## Value

A `net_mlvar_bayes` object (also inheriting `net_mlvar`), a named list
of three netobjects (`temporal`, `contemporaneous`, `between`) with
posterior-summary attributes.
[`coefs()`](https://mohsaqr.github.io/idiographic/reference/coefs.md)
returns a tidy table with `estimate` (posterior median), `posterior_sd`,
`ci_lower`, `ci_upper`, `p` (one-tailed), and `significant` (95% CI
excludes 0). Posterior draws and the max Gelman-Rubin PSR are kept in
attributes.

## Details

The sampler alternates five conjugate full-conditional draws per
iteration: the latent person means `mu_i` (Gaussian), the fixed temporal
matrix `B` (matrix-normal), the within residual covariance `Sigma_W`
(inverse-Wishart), the grand mean `alpha` (Gaussian), and the between
covariance `Sigma_B` (inverse-Wishart). The lagged predictor is
recentred on the current `mu_i` draw every iteration (latent mean
centring). Data are globally standardized first (matching `mlVAR`'s
`scale = TRUE`); the first observation of each block is used only as a
lag (condition-on-first).

Validated to statistical (Monte-Carlo-error) equivalence against real
Mplus 9 DSEM output on standardized synthetic panels: posterior medians
of `B`, `Sigma_W`, `Sigma_B` agree with Mplus to well within a posterior
SD.

## See also

[`fit_mlvar()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar.md)
(frequentist lmer path),
[`fit_mlvar_mplus()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar_mplus.md)
(true-Mplus wrapper).

## Examples

``` r
# \donttest{
set.seed(1)
n_id <- 10; n_t <- 40; vars <- c("A", "B")
rows <- lapply(seq_len(n_id), function(i) {
  y <- matrix(0, n_t, 2)
  for (t in 2:n_t) y[t, ] <- c(0.3, 0.15) * y[t - 1, ] + rnorm(2)
  data.frame(id = i, beep = seq_len(n_t), A = y[, 1], B = y[, 2])
})
d <- do.call(rbind, rows)
fit <- fit_mlvar_bayes(d, vars = vars, id = "id", beep = "beep",
                         n_iter = 500, seed = 1)
print(fit)
#> Bayesian mlVAR (Mplus DSEM-targeted, temporal = fixed): 10 subjects, 390 observations, 2 variables
#>   MCMC: 2 chains x 500 iter (250 burn-in), 500 draws | max PSR = 1.023
#>   Temporal 95% CIs excluding 0: 2 / 4
#> 
#>   Temporal [directed]
#>     weights [-0.088, 0.252]  |  +2 / -2 edges
#>           A     B
#>     A  0.25 -0.09
#>     B -0.07  0.13
#> 
#>   Contemporaneous [undirected]
#>     weights [-0.003, -0.003]  |  +0 / -1 edges
#>       A B
#>     A 0 0
#>     B 0 0
#> 
#>   Between [undirected]
#>     weights [0.312, 0.312]  |  +1 / -0 edges
#>          A    B
#>     A 0.00 0.31
#>     B 0.31 0.00
#> 
#>   coefs(x) posterior median/SD/CI | matrices(x) | edges(x) | summary(x)
coefs(fit)
#>   outcome predictor    estimate posterior_sd    ci_lower   ci_upper     p
#> 1       A         A  0.25209120   0.05021821  0.15945833 0.34723692 0.000
#> 2       A         B -0.06643236   0.04845493 -0.16844721 0.01897108 0.086
#> 3       B         A -0.08835699   0.05652692 -0.20220844 0.02199014 0.062
#> 4       B         B  0.12768325   0.05189932  0.02778123 0.22516873 0.012
#>   significant
#> 1        TRUE
#> 2       FALSE
#> 3       FALSE
#> 4        TRUE
# }
```
