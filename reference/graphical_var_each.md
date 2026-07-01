# Fit a graphical VAR for every subject

Applies
[`graphical_var()`](https://mohsaqr.github.io/idiographic/reference/graphical_var.md)
to each subject separately, returning one person-specific network per
individual — the idiographic "all individuals" workflow. Subjects that
cannot be fit (too few lag pairs after listwise deletion) are dropped
with a warning.

## Usage

``` r
graphical_var_each(
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
  day, beep columns for panel/ESM data.

- vars:

  Character vector of variable names.

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
  [`graphical_var()`](https://mohsaqr.github.io/idiographic/reference/graphical_var.md)
  (e.g. `n_lambda`, `gamma`, `scale`).

## Value

A named list of `gvar_result` objects (class `gvar_list`), one element
per subject, named by subject id.
