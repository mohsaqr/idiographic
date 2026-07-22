# Build an Mplus-backed multilevel VAR network

Runs the Mplus Bayesian estimator exposed by
`mlVAR::mlVAR(estimator = "Mplus")` and converts the returned posterior
summaries into idiographic's network/tidy accessors. This is a true
Mplus backend: Mplus must be installed and discoverable by
[`MplusAutomation::detectMplus()`](https://michaelhallquist.github.io/MplusAutomation/reference/detectMplus.html).

## Usage

``` r
fit_mlvar_mplus(
  data,
  vars,
  id,
  day = NULL,
  beep = NULL,
  lags = 1L,
  temporal = c("fixed", "correlated", "orthogonal", "default"),
  contemporaneous = c("fixed", "correlated", "orthogonal", "default"),
  nCores = 1L,
  scale = TRUE,
  scaleWithin = FALSE,
  MplusSave = TRUE,
  MplusName = "mlVAR_mplus",
  iterations = "(2000)",
  chains = nCores,
  signs,
  min_obs = NULL,
  subject = NULL,
  workdir = NULL,
  verbose = TRUE,
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

  Character string naming the day/session column, or `NULL`. Mplus
  estimation in `mlVAR` does not directly support `day`; when supplied
  it is passed through so `mlVAR` can prepare the row order, but `mlVAR`
  will warn about the Mplus limitation.

- beep:

  Character string naming the measurement-occasion column, or `NULL`.

- lags:

  Integer lag order. The Mplus backend currently supports `1`.

- temporal, contemporaneous:

  Random-effect structure passed to `mlVAR`. Supported Mplus values are
  `"fixed"`, `"correlated"`, `"orthogonal"`, and `"default"`.

- nCores:

  Number of Mplus processors/chains.

- scale, scaleWithin:

  Standardization options passed to `mlVAR`.

- MplusSave:

  Logical. Keep Mplus input/output files in the working directory?
  Default `TRUE`.

- MplusName:

  File stem for Mplus input/output files.

- iterations:

  Mplus `BITERATIONS` string, e.g. `"(2000)"`.

- chains:

  Number of Mplus chains. Defaults to `nCores`.

- signs:

  Optional sign matrix for contemporaneous random effects.

- min_obs:

  Integer or `NULL`. Keep only subjects with at least this many
  observations before fitting.

- subject:

  Optional vector naming the exact subject(s) to analyse.

- workdir:

  Directory in which Mplus files should be written/run. Default uses the
  current working directory.

- verbose:

  Logical. Show progress from `mlVAR`/Mplus.

- ...:

  Additional arguments passed to
  [`mlVAR::mlVAR()`](https://rdrr.io/pkg/mlVAR/man/mlVAR.html).

## Value

A `net_mplus` object, also inheriting from `net_mlvar`, with temporal,
contemporaneous, and between networks plus Mplus metadata in attributes.
The original `mlVAR`/Mplus object is available as `attr(x, "mplus")`.

## See also

[`fit_mlvar()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar.md)

## Examples

``` r
if (FALSE) { # \dontrun{
fit <- fit_mlvar_mplus(
  data, vars = c("A", "B", "C"), id = "id", beep = "time",
  temporal = "fixed", contemporaneous = "fixed",
  MplusName = "my_mplus_mlvar"
)
edges(fit)
attr(fit, "mplus")$output$summaries
} # }
```
