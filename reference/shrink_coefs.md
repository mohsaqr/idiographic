# Shrink each person's coefficient towards the pooled effect

A person measured over few occasions has a noisy coefficient, and taking
it at face value overstates how unusual they are. Empirical-Bayes
shrinkage pulls each estimate towards the pooled effect by an amount
that depends on how well that person was measured:

## Usage

``` r
shrink_coefs(
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

A `data.frame` of one row per person per term, with class
`idiographic_shrunk`.

## Details

\$\$\hat\theta_i^{EB} = \bar\theta + \frac{\tau^2}{\tau^2 + v_i}
(\hat\theta_i - \bar\theta)\$\$

`weight` is that fraction: 1 means the person's own estimate is kept
as-is, 0 means it carries no information of its own and is replaced by
the pooled value. When `tau` is zero – no real heterogeneity – every
person shrinks all the way to the pooled effect, which is the correct
answer.

These are the estimates to cluster on if you cluster at all: clustering
raw coefficients finds groups partly in the estimation noise.

## Examples

``` r
fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name",
              time = "day", scope = "individual")
shrink_coefs(fit)
#> SHRUNKEN PERSON EFFECTS
#>   People   36
#>   Terms    2
#> 
#>   subject   term              raw      S.E.   weight   shrunken
#> ---------------------------------------------------------------
#>   Aisha     (Intercept)   60.2331    4.5432    0.973    59.6401
#>   Alice     (Intercept)   41.3573    3.2900    0.986    41.3155
#>   Anika     (Intercept)   22.4214    5.0940    0.966    22.9672
#>   Astrid    (Intercept)   57.4470    6.3689    0.948    56.4568
#>   Bjorn     (Intercept)   35.0610    4.5007    0.973    35.1522
#>   Bob       (Intercept)   35.8825    8.5933    0.909    36.1181
#>   Charlie   (Intercept)   29.2662    5.9326    0.954    29.6857
#>   Diana     (Intercept)   74.9567   10.8393    0.862    69.9391
#>   Erik      (Intercept)   25.3872    4.0320    0.978    25.6696
#>   Eve       (Intercept)   28.6605    3.8959    0.980    28.8585
#>   Fatima    (Intercept)   42.0655    7.9466    0.921    41.7816
#>   Frank     (Intercept)   24.7052   10.0727    0.879    26.3709
#> 
#>   ... 60 more rows.
#> 
#>   weight = how much of the person's own estimate is kept
```
