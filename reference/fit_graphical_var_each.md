# Fit a graphical VAR for every subject

Applies
[`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md)
to each subject separately, returning one person-specific network per
individual — the idiographic "all individuals" workflow. Subjects that
cannot be fit (too few lag pairs after listwise deletion) are dropped
with a warning.

## Usage

``` r
fit_graphical_var_each(
  data,
  vars,
  id,
  day = NULL,
  beep = NULL,
  min_obs = NULL,
  ...
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

  Character. The subject-id column (required here).

- day:

  Character. Name of the day/session column. Default: NULL.

- beep:

  Character. Name of the beep/measurement column. Default: NULL.

- min_obs:

  Integer or `NULL`. Keep only subjects with at least this many
  observations (counts taken from `data`). Default `NULL`.

- ...:

  Further arguments passed to
  [`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md)
  (e.g. `n_lambda`, `gamma`, `scale`).

## Value

A named list of `gvar_result` objects (class `gvar_list`), one element
per subject, named by subject id.

## Examples

``` r
set.seed(2)
d <- data.frame(id = rep(1:2, each = 35),
                A = rnorm(70), B = rnorm(70))
fits <- fit_graphical_var_each(d, vars = c("A", "B"), id = "id",
                               n_lambda = 3, scale = FALSE)
names(fits)
#> [1] "1" "2"
```
