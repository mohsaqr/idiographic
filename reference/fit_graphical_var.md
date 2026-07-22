# Graphical VAR Estimation

Estimate a graphical vector autoregressive (GVAR) model from time series
or panel data. Jointly estimates a sparse temporal network (L1-penalized
VAR coefficients) and a sparse contemporaneous network (graphical lasso
on residuals) using EBIC model selection over a lambda grid.

## Usage

``` r
fit_graphical_var(
  data,
  vars,
  id = NULL,
  day = NULL,
  beep = NULL,
  lags = 1L,
  n_lambda = 50L,
  gamma = 0.5,
  scale = TRUE,
  center_within = TRUE,
  lambda_min_ratio = 0.05,
  lambda_min_kappa = NULL,
  lambda_min_beta = NULL,
  penalize_diagonal = TRUE,
  lambda_beta = NULL,
  lambda_kappa = NULL,
  regularize_mat_beta = NULL,
  regularize_mat_kappa = NULL,
  maxit_in = 100L,
  maxit_out = 100L,
  delete_missings = TRUE,
  likelihood = c("unpenalized", "penalized"),
  ebic_tol = 1e-04,
  mimic = "current",
  verbose = FALSE,
  min_obs = NULL,
  subject = NULL
)
```

## Arguments

- data:

  A data.frame or matrix with columns for variables, and optionally id,
  day, beep columns for panel/ESM data. A prepared list containing
  numeric matrices `data_c` (current responses) and `data_l` (lagged
  design, with or without an intercept column) is also accepted.

- vars:

  Character vector of variable names. May be omitted for prepared input
  when `data_c` has column names.

- id:

  Character. Name of the person-ID column. If NULL, assumes single
  subject.

- day:

  Character. Name of the day/session column. Default: NULL.

- beep:

  Character. Name of the beep/measurement column. Default: NULL.

- lags:

  Positive integer vector of explicit lags to include. Default: 1.

- n_lambda:

  Integer scalar, or a two-value vector giving the number of beta and
  kappa penalties. The latter can be named, for example
  `c(beta = 30, kappa = 20)`, or unnamed in beta/kappa order. Default:
  50.

- gamma:

  Numeric. EBIC hyperparameter (0 = BIC, higher = sparser). Default:
  0.5.

- scale:

  Logical. Whether to standardize variables. Default: TRUE.

- center_within:

  Logical. Whether to center within person when more than one id is
  present (removes between-person variance). Default: TRUE.

- lambda_min_ratio:

  Numeric scalar, or a two-value beta/kappa vector. Ratio of min/max
  lambda unless overridden per-dimension. Default: 0.05.

- lambda_min_kappa, lambda_min_beta:

  Numeric or `NULL`. Per-dimension min/max lambda ratios (matching
  `graphicalVAR`'s `lambda_min_kappa` / `lambda_min_beta`). When `NULL`,
  fall back to `lambda_min_ratio`.

- penalize_diagonal:

  Logical. Penalize the autoregressive diagonal in beta. Default: TRUE
  (matches `graphicalVAR`).

- lambda_beta:

  Numeric scalar (or vector), or `NULL`. When supplied, the temporal
  penalty is pinned to this value instead of being EBIC-selected over a
  grid – matching `graphicalVAR`'s `lambda_beta` argument (e.g.
  `lambda_beta = 0.1`). Default `NULL` (EBIC grid).

- lambda_kappa:

  Numeric scalar (or vector), or `NULL`. As `lambda_beta` but for the
  contemporaneous (kappa) penalty.

- regularize_mat_beta:

  Optional numeric/logical matrix (`p x p` or `p x (p+1)`) of
  per-element beta penalty multipliers (matches `graphicalVAR`'s
  `regularize_mat_beta`). `NULL` uses `penalize_diagonal`.

- regularize_mat_kappa:

  Optional `p x p` numeric/logical matrix of per-element kappa penalty
  multipliers (matches `graphicalVAR`'s `regularize_mat_kappa`). `NULL`
  penalizes all off-diagonals.

- maxit_in, maxit_out:

  Integer. Max inner (beta) / outer (beta-kappa) iterations. Defaults
  100 (matches `maxit.in` / `maxit.out`).

- delete_missings:

  Logical. Drop rows with missing current/lagged values. Default TRUE
  (matches `deleteMissings`).

- likelihood:

  Either `"unpenalized"` (default; refit precision for the EBIC,
  matching `graphicalVAR`) or `"penalized"` (use the regularized kappa
  directly).

- ebic_tol:

  Numeric. Tolerance for the EBIC tie-break. Default 1e-4.

- mimic:

  Character. Only `"current"` is supported. Legacy modes error
  explicitly because idiographic does not claim equivalence to them.

- verbose:

  Logical. Emit progress messages. Default FALSE.

- min_obs:

  Integer or `NULL`. Keep only subjects with at least this many
  observations (counts taken from `data`). Default `NULL`.

- subject:

  Optional vector naming the exact subject(s) to analyse. Default `NULL`
  (all subjects).

## Value

A list of class `gvar_result` containing:

- beta:

  Temporal coefficient matrix, outcome x (intercept + predictors), in
  `graphicalVAR`'s convention.

- temporal:

  The first requested p x p temporal layer as `[outcome, predictor]`;
  unchanged for the default lag 1 fit.

- temporal_layers:

  Named p x p coefficient matrices for every lag.

- kappa:

  Precision matrix (p x p, symmetric).

- PCC:

  Partial contemporaneous correlations `-cov2cor(kappa)`, diagonal
  zeroed.

- PDC:

  Partial directed correlations.

- contemporaneous:

  Alias for `PCC`.

- labels:

  Variable names.

- n_obs:

  Number of valid lag-pair observations.

- lambda_beta, lambda_kappa:

  Selected penalties.

- gamma, EBIC:

  EBIC gamma used and the selected EBIC.

## Details

This is a clean-room reimplementation of the Rothman/Epskamp two-step
estimator that is **numerically equivalent to**
[`graphicalVAR::graphicalVAR()`](https://rdrr.io/pkg/graphicalVAR/man/graphicalVAR.html):
identical data preparation (global scaling, optional within-person
centering, intercept column, lag-1 construction within id/day blocks),
identical lambda grids (`generate_lambdas`), the coupled MRCE
beta-update / glasso kappa-update loop, the unpenalized-likelihood EBIC,
and the same tie-broken model selection. The committed end-to-end
regression tests use tolerance `1e-6`, covering both well-conditioned
and numerically difficult fits. That equivalence claim is limited to
`mimic = "current"` and `lags = 1`; multiple lags are an idiographic
extension and are labelled as such in the returned equivalence metadata.

## References

Epskamp, S., Waldorp, L. J., Mottus, R., & Borsboom, D. (2018). The
Gaussian Graphical Model in Cross-Sectional and Time-Series Data.
*Multivariate Behavioral Research*, 53(4), 453-480.

Rothman, A. J., Levina, E., & Zhu, J. (2010). Sparse multivariate
regression with covariance estimation. *JCGS*, 19(4), 947-962.

## Examples

``` r
set.seed(1)
d <- data.frame(A = rnorm(60), B = rnorm(60))
fit <- fit_graphical_var(d, vars = c("A", "B"), n_lambda = 3,
                         scale = FALSE)
fit$temporal
#>   A B
#> A 0 0
#> B 0 0
fit$contemporaneous
#>   A B
#> A 0 0
#> B 0 0
```
