# Momentary self-regulated-learning experience-sampling data

An anonymized intensive longitudinal data set in which 41 students rated
their momentary self-regulation, motivation, and anxiety several times
per day over the course of a study, giving roughly 70 to 80 occasions
each. Unlike the once-per-day
[srl](https://mohsaqr.github.io/idiographic/reference/srl.md) panel, the
occasions here are within-day momentary assessments, so the series are
well suited to person-specific (idiographic) VAR, graphical VAR, and
unified SEM. The data are fully anonymized: the participant identifiers
are fictional names, and the calendar dates have been shifted by a
constant offset (preserving all within-person spacing) so that no real
dates or identities remain.

## Usage

``` r
esm_srl
```

## Format

A `data.frame` with 2820 rows and 12 columns:

- name:

  Fictional participant identifier (41 unique students).

- occasion:

  Within-person occasion index, ordered in time.

- date:

  Anonymized (constant-shifted) assessment date.

- efficacy:

  Momentary self-efficacy (motivation).

- value:

  Momentary task value (motivation).

- planning:

  Momentary planning (self-regulation).

- monitoring:

  Momentary monitoring (self-regulation).

- effort:

  Momentary effort regulation (self-regulation).

- regulation:

  Momentary strategy regulation (self-regulation).

- motivated:

  Momentary felt motivation (motivation).

- enjoyment:

  Momentary enjoyment (motivation).

- anxiety:

  Momentary anxiety.

## Details

The nine indicators span three domains: self-regulation (`planning`,
`monitoring`, `effort`, `regulation`), motivation (`efficacy`, `value`,
`motivated`, `enjoyment`), and `anxiety`. Each variable is on a 0-100
scale. Rows are one person-occasion each, ordered within person by
`occasion`.

## Examples

``` r
data(esm_srl)
summary(esm_srl)
#>         name         occasion          date               efficacy     
#>  Length   :2820   Min.   : 1.00   Min.   :2026-02-15   Min.   :  0.00  
#>  N.unique :  41   1st Qu.:18.00   1st Qu.:2026-07-06   1st Qu.: 34.55  
#>  N.blank  :   0   Median :35.00   Median :2026-07-15   Median : 55.70  
#>  Min.nchar:   3   Mean   :35.48   Mean   :2026-07-09   Mean   : 53.51  
#>  Max.nchar:   5   3rd Qu.:52.00   3rd Qu.:2026-07-26   3rd Qu.: 74.42  
#>                   Max.   :79.00   Max.   :2026-08-07   Max.   :100.00  
#>                                                        NAs    :3       
#>      value           planning        monitoring         effort      
#>  Min.   :  0.00   Min.   :  0.00   Min.   :  0.00   Min.   :  0.00  
#>  1st Qu.: 37.04   1st Qu.: 36.73   1st Qu.: 26.04   1st Qu.: 40.00  
#>  Median : 58.54   Median : 58.06   Median : 54.84   Median : 61.64  
#>  Mean   : 55.95   Mean   : 56.61   Mean   : 50.89   Mean   : 58.65  
#>  3rd Qu.: 76.52   3rd Qu.: 78.85   3rd Qu.: 75.00   3rd Qu.: 80.60  
#>  Max.   :100.00   Max.   :100.00   Max.   :100.00   Max.   :100.00  
#>  NAs    :5        NAs    :2        NAs    :3        NAs    :4       
#>    regulation       motivated        enjoyment         anxiety      
#>  Min.   :  0.00   Min.   :  0.00   Min.   :  0.00   Min.   :  0.00  
#>  1st Qu.: 32.54   1st Qu.: 37.50   1st Qu.: 34.62   1st Qu.: 33.33  
#>  Median : 57.50   Median : 61.54   Median : 57.78   Median : 58.82  
#>  Mean   : 54.55   Mean   : 56.51   Mean   : 55.47   Mean   : 57.20  
#>  3rd Qu.: 78.48   3rd Qu.: 77.78   3rd Qu.: 77.78   3rd Qu.: 82.72  
#>  Max.   :100.00   Max.   :100.00   Max.   :100.00   Max.   :100.00  
#>  NAs    :4        NAs    :2        NAs    :15       NAs    :3       
head(esm_srl)
#>    name occasion       date efficacy    value planning monitoring    effort
#> 1 Amara        1 2026-06-27 13.11475 51.66667 91.95402   84.93151  84.05797
#> 2 Amara        2 2026-06-28 90.16393 58.33333 77.01149   49.31507  81.15942
#> 3 Amara        3 2026-06-28 67.21311 91.66667 32.18391   89.04110  44.92754
#> 4 Amara        4 2026-06-29 52.45902 65.00000 64.36782   83.56164 100.00000
#> 5 Amara        5 2026-06-29 83.60656 35.00000 67.81609   23.28767  50.72464
#> 6 Amara        6 2026-06-30 75.40984 71.66667 33.33333   21.91781  86.95652
#>   regulation motivated enjoyment anxiety
#> 1   58.10811  20.00000  33.33333     100
#> 2   33.78378  52.94118  33.33333      94
#> 3   33.78378  58.82353  34.72222      98
#> 4   43.24324  29.41176  31.94444     100
#> 5   85.13514  41.17647  62.50000     100
#> 6   60.81081  28.23529  77.77778      93
```
