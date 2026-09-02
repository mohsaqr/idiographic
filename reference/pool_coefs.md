# Pool person-specific coefficients, separating real spread from noise

Runs a random-effects meta-analysis across people, one per term,
treating each person as a study with an estimate and a standard error.

## Usage

``` r
pool_coefs(
  x,
  term = NULL,
  scope = "individual",
  model = NULL,
  subgroup = NULL,
  conf_level = 0.95
)
```

## Arguments

- x:

  An `idiographic_fit` with individual-scope coefficients.

- term:

  Optional filter on the coefficient name.

- scope:

  Which scope's coefficients to pool. Individual, necessarily.

- model, subgroup:

  Optional filters.

- conf_level:

  Confidence level for the pooled interval.

## Value

A `data.frame` of one row per term, with class `idiographic_pooled`.

## Details

The comparison to read first is **`sd_observed` against `tau`**. The
former is the spread you can see in the person-specific coefficients;
the latter is how much of it is real once each person's own estimation
error is taken out. If they are close, people genuinely differ. If `tau`
is much the smaller, most of the apparent heterogeneity is measurement
noise from short series, and any subgroups found by clustering those
coefficients are partly an artefact of that noise.

- `estimate`:

  Random-effects pooled effect, with `tau` in its weights, so people are
  not weighted purely by how much data they happen to have.

- `tau`:

  Estimated standard deviation of the *true* person effects
  (DerSimonian-Laird). Zero means the people are indistinguishable once
  noise is accounted for.

- `i2`:

  Share of observed variation that is real rather than sampling error,
  from 0 to 1.

- `q`, `q_p`:

  Cochran's Q and its p-value: is there *any* real heterogeneity at all?

Intervals use the **Hartung-Knapp** variance with `t` on `k - 1` degrees
of freedom, `k` being the number of people. The textbook random-effects
standard error treats `tau` as known when it was estimated, and
under-covers as a result: with 10 people it gave 0.930 coverage in
simulation where 0.95 was claimed, against 0.945 for the adjustment used
here. The adjustment can only ever widen the interval.

## Read `q_p` with caution

Cochran's Q assumes each person's standard error is *known*. Here it is
estimated from that person's own handful of occasions, which inflates Q.
In simulation on data with **no** real heterogeneity at all, `q_p` fell
below 0.05 in **13%** of runs rather than 5% – a false-positive rate
roughly 2.6 times what it claims, and it did not improve when each
person had 60 occasions instead of 25.

So treat a small `q_p` as suggestive, not decisive, and read the *size*
of `tau` against `sd_observed` instead. Those are well behaved: across
the same simulations `tau` recovered true values of 0, 0.30 and 0.60 as
0.06, 0.30 and 0.59, and the pooled estimate was unbiased throughout.

Needs coefficients that carry standard errors, so it works on
[`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md),
[`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md)
and
[`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md)
results.
[`fit_ml()`](https://pak.dynasite.org/idiographic/reference/fit_ml.md)
does not report them and is refused rather than silently pooled as if
every person were measured equally well.

## Examples

``` r
fit <- fit_lm(srl, y = "effort", x = c("efficacy", "planning"),
              id = "name", time = "day", scope = "individual")
pool_coefs(fit)
#> POOLED PERSON EFFECTS
#>   Method   random effects (DerSimonian-Laird)
#>   People   36
#>   Terms    3
#> 
#>   term           k    pooled           95% CI   sd_obs      tau      I2      Q p
#> --------------------------------------------------------------------------------
#>   (Intercept)   36   28.3401   [19.28, 37.41]   22.892   26.076   0.973   <1e-04
#>   efficacy      36    0.2379     [0.15, 0.33]    0.274    0.255   0.907   <1e-04
#>   planning      36    0.3131     [0.22, 0.41]    0.282    0.251   0.909   <1e-04
#> 
#>   sd_obs = spread you see;  tau = spread that is REAL
#>   I2     = share of the observed spread that is real
```
