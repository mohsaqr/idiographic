# GIMME: Group Iterative Multiple Model Estimation

Estimates person-specific directed networks from intensive longitudinal
data using the unified Structural Equation Modeling (uSEM) framework.
Implements a data-driven search that identifies:

1.  **Group-level paths**: Directed edges present for a majority
    (default 75\\

2.  **Individual-level paths**: Additional edges specific to each
    person, found after group paths are established.

Uses `lavaan` for SEM estimation and modification indices. Accepts a
single data frame with an ID column (not CSV directories).

## Usage

``` r
fit_gimme(
  data,
  vars,
  id,
  time = NULL,
  day = NULL,
  beep = NULL,
  min_obs = NULL,
  subject = NULL,
  ar = TRUE,
  standardize = FALSE,
  groupcutoff = 0.75,
  subcutoff = 0.75,
  paths = NULL,
  exogenous = NULL,
  hybrid = FALSE,
  VAR = FALSE,
  rmsea_cutoff = 0.05,
  srmr_cutoff = 0.05,
  nnfi_cutoff = 0.95,
  cfi_cutoff = 0.95,
  n_excellent = 2L,
  seed = NULL,
  group_correct = "Bonferroni Group",
  indiv_correct = "Bonferroni",
  alpha = 0.05,
  stop_crit = "model fit",
  subgroup = FALSE,
  outcome = NULL,
  conv_vars = NULL,
  mult_vars = NULL,
  lv_model = NULL,
  lasso_model_crit = NULL,
  ms_allow = FALSE,
  ordered = NULL,
  dir_prop_cutoff = 0,
  out = NULL,
  sep = NULL,
  header = NULL,
  plot = FALSE,
  sub_feature = "lag & contemp",
  sub_method = "Walktrap",
  sub_sim_thresh = "lowest",
  confirm_subgroup = NULL,
  conv_length = 16,
  conv_interval = 1,
  mean_center_mult = FALSE,
  diagnos = FALSE,
  ms_tol = 1e-05,
  lv_estimator = "miiv",
  lv_scores = "regression",
  lv_miiv_scaling = "first.indicator",
  lv_final_estimator = "miiv"
)
```

## Arguments

- data:

  A `data.frame` in long format with columns for person ID, time-varying
  variables, and optionally a time/beep column.

- vars:

  Character vector of variable names to model.

- id:

  Character string naming the person-ID column.

- time:

  Character string naming the time/order column, or `NULL`. When
  provided, data is sorted by `id` then `time` before lagging.

- day:

  Character string naming the day/session column, or `NULL`. When
  supplied, lag-1 pairs are formed only within the same `(id, day)`
  block, so a lag never crosses the overnight gap.

- beep:

  Character string naming the measurement-occasion column, or `NULL`.
  Used (with `day`) to order observations when `time` is not given.

- min_obs:

  Integer or `NULL`. Keep only subjects with at least this many
  observations (counts taken from `data`).

- subject:

  Optional vector naming the exact subject(s) to analyse.

- ar:

  Logical. If `TRUE` (default), autoregressive paths (each variable
  predicting itself at lag 1) are included as fixed paths.

- standardize:

  Logical. If `TRUE` (default `FALSE`), variables are standardized per
  person before estimation. Note: the returned coefficient network
  (`$coefs`, `$psi`, `$temporal_avg`, `$contemporaneous_avg`,
  `$group_paths`) is unaffected because idiographic extracts the
  standardized lavaan solution (`lavInspect(fit, "std")`), which is
  invariant to input scaling. Only the scale-dependent `$fit` statistics
  (chisq, aic, bic) change.

- groupcutoff:

  Numeric between 0 and 1. Proportion of individuals for whom a path
  must be significant to be added at group level. Default `0.75`.

- subcutoff:

  Numeric. Subgroup cutoff (default 0.75, matching `gimme`); only
  relevant to subgrouping, which is not implemented.

- paths:

  Character vector of lavaan-syntax paths to force into the model (e.g.,
  `"V2~V1lag"`). Default `NULL`.

- exogenous:

  Character vector of variable names to treat as exogenous. Default
  `NULL`.

- hybrid:

  Logical. If `TRUE`, also searches residual covariances. Default
  `FALSE`.

- VAR:

  Logical. If `TRUE`, fit a standard VAR: only lagged directed paths are
  searched and contemporaneous relations are estimated as residual
  covariances (no directed contemporaneous paths). Matches
  `gimme(VAR = TRUE)`. Default `FALSE`.

- rmsea_cutoff:

  Numeric. RMSEA threshold for excellent fit (default 0.05).

- srmr_cutoff:

  Numeric. SRMR threshold for excellent fit (default 0.05).

- nnfi_cutoff:

  Numeric. NNFI/TLI threshold for excellent fit (default 0.95).

- cfi_cutoff:

  Numeric. CFI threshold for excellent fit (default 0.95).

- n_excellent:

  Integer. Number of fit indices that must be excellent to stop
  individual search. Default `2`.

- seed:

  Integer or `NULL`. Random seed for reproducibility.

- group_correct:

  Group-level multiple-comparison correction. Use `"Bonferroni Group"`
  (the default) to divide `alpha` by the number of people,
  `"Bonferroni Paths"` to divide it by the number of eligible paths,
  `"fdr"` for Benjamini-Hochberg correction, or a single number in
  `(0, 1)` to set the group alpha directly. The legacy misspelling
  `"Bonferoni Group"` is accepted with a deprecation warning.

- indiv_correct:

  Individual-level multiple-comparison correction. Use `"Bonferroni"`
  (the default) or `"fdr"`.

- alpha:

  Base significance level for group and individual searches. Default
  `0.05`.

- stop_crit:

  Individual-search stopping rule. `"standard"` stops when fit is
  adequate or no significant path remains; `"model fit"` (the default)
  keeps adding the largest-MI path, regardless of significance, until
  fit is adequate; and `"significance"` keeps adding significant paths
  even after fit is adequate.

- subgroup:

  Logical. Subgrouping (S-GIMME) is not implemented; `TRUE` raises an
  error pointing to
  [`gimme::gimme()`](https://rdrr.io/pkg/gimme/man/gimmeSEM.html).
  Default `FALSE`.

- outcome, conv_vars, mult_vars, lv_model, lasso_model_crit, ms_allow,
  ordered, dir_prop_cutoff:

  Accepted for
  [`gimme::gimme()`](https://rdrr.io/pkg/gimme/man/gimmeSEM.html) API
  parity but not implemented (latent variable / fMRI-convolution /
  multiplied-term / LASSO / ordinal / multiple-solutions /
  directionality features). A non-default value raises an error pointing
  to [`gimme::gimme()`](https://rdrr.io/pkg/gimme/man/gimmeSEM.html).

- out, sep, header, plot:

  Accepted for
  [`gimme::gimme()`](https://rdrr.io/pkg/gimme/man/gimmeSEM.html) API
  parity. idiographic reads a `data.frame` (not a CSV directory), so
  non-default `out`, `sep`, and `header` values emit a warning and have
  no effect. It returns an object you plot with
  [`plot_gimme()`](https://mohsaqr.github.io/idiographic/reference/plot_gimme.md);
  `plot = TRUE` emits a message.

- sub_feature, sub_method, sub_sim_thresh, confirm_subgroup,
  conv_length, conv_interval, mean_center_mult, diagnos, ms_tol,
  lv_estimator, lv_scores, lv_miiv_scaling, lv_final_estimator:

  Accepted for
  [`gimme::gimme()`](https://rdrr.io/pkg/gimme/man/gimmeSEM.html) API
  parity. These configure the unsupported subgrouping / convolution /
  multiplied-term / multiple-solutions / latent-variable features and
  are inert here (their parent feature is guarded above).

## Value

An S3 object of class `"net_gimme"` containing:

- `temporal`:

  p x p matrix of group-level temporal (lagged) path counts – entry
  `[i,j]` = number of individuals with path j(t-1)-\>i(t).

- `contemporaneous`:

  p x p matrix of group-level contemporaneous path counts – entry
  `[i,j]` = number of individuals with path j(t)-\>i(t).

- `coefs`:

  List of per-person q x (q + p) coefficient matrices (q non-exogenous
  rows; columns = `[lagged, contemporaneous]`).

- `psi`:

  List of per-person `q x (q + p)` standardized residual covariance
  matrices, with non-exogenous current variables in rows and
  `c(lag_names, varnames)` in columns, matching
  [`gimme::gimme()`](https://rdrr.io/pkg/gimme/man/gimmeSEM.html)'s
  returned `psi` contract.

- `fit`:

  Data frame of per-person fit indices (chisq, df, pvalue, rmsea, srmr,
  nnfi, cfi, bic, aic, logl, status).

- `path_counts`:

  p x 2p matrix: how many individuals have each path.

- `paths`:

  List of per-person character vectors of lavaan path syntax.

- `group_paths`:

  Character vector of group-level paths found.

- `individual_paths`:

  List of per-person character vectors of individual-level paths (beyond
  group).

- `syntax`:

  List of per-person full lavaan syntax strings.

- `labels`:

  Character vector of variable names.

- `n_subjects`:

  Integer. Number of individuals.

- `n_obs`:

  Integer vector. Time points per individual.

- `config`:

  List of configuration parameters.

## See also

[`fit_mlvar`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar.md),
[`fit_graphical_var`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md),
[`as_netobject`](https://mohsaqr.github.io/idiographic/reference/as_netobject.md)

## Examples

``` r
# \donttest{
# Create simple panel data (3 subjects, 4 variables, 50 time points).
set.seed(42)
n_sub <- 3; n_t <- 50; vars <- paste0("V", 1:4)
rows <- lapply(seq_len(n_sub), function(i) {
  d <- as.data.frame(matrix(rnorm(n_t * 4), ncol = 4))
  names(d) <- vars; d$id <- i; d
})
panel <- do.call(rbind, rows)
res <- fit_gimme(panel, vars = vars, id = "id")
print(res)
#> GIMME Network Analysis
#> ------------------------------ 
#> Subjects:   3 
#> Variables:  4  ( V1, V2, V3, V4 )
#> AR paths:   yes 
#> Hybrid:     no 
#> 
#> Group-level paths found: 0 
#> 
#> Individual-level paths:  mean 1.3, range 0-3
#> 
#> Proportion of subjects with each path:
#> 
#>   Temporal [directed]
#>     weights [0.333, 1.000]  |  +6 / -0 edges
#>        V1 V2   V3   V4
#>     V1  1  0 0.00 0.00
#>     V2  0  1 0.33 0.33
#>     V3  0  0 1.00 0.00
#>     V4  0  0 0.00 1.00
#> 
#>   Contemporaneous [directed]
#>     weights [0.333, 0.333]  |  +2 / -0 edges
#>        V1   V2 V3   V4
#>     V1  0 0.00  0 0.00
#>     V2  0 0.00  0 0.00
#>     V3  0 0.00  0 0.33
#>     V4  0 0.33  0 0.00
#> 
#>   plot(x)  (faithful gimme-style mixed network) | plot(x, layer = "temporal") 
#>   edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)
# }
```
