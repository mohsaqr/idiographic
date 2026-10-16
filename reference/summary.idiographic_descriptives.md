# Summarise person descriptives by variable

One row per variable, aggregating the per-person rows of a
[`describe_persons()`](https://pak.dynasite.org/idiographic/reference/describe_persons.md)
result: the number of persons, the mean and standard deviation of the
person means, the average within-person standard deviation, and, when
the result was computed with `detail = "full"`, the number and share of
persons whose linear trend is significant at `alpha`. With no trends
present, the expected share is `alpha`.

## Usage

``` r
# S3 method for class 'idiographic_descriptives'
summary(object, alpha = 0.05, ...)

# S3 method for class 'idiostats_descriptives'
summary(object, alpha = 0.05, ...)
```

## Arguments

- object:

  A
  [`describe_persons()`](https://pak.dynasite.org/idiographic/reference/describe_persons.md)
  result.

- alpha:

  Significance level for counting linear trends.

- ...:

  Ignored.

## Value

A data frame with one row per variable and columns `variable`,
`persons`, `mean_of_means`, `sd_of_means`, `mean_sd_within`,
`significant_trends`, and `trend_share` (the last two `NA` unless
`detail = "full"`).

## Examples

``` r
d <- describe_persons(srl, id = "name", vars = c("efficacy", "effort"),
                      time = "day", detail = "full")
summary(d)
#>   variable persons mean_of_means sd_of_means mean_sd_within significant_trends
#> 1 efficacy      36      54.03965    15.90734       21.27906                  1
#> 2   effort      36      58.97604    14.54039       22.25366                  1
#>   trend_share
#> 1  0.02777778
#> 2  0.02777778
```
