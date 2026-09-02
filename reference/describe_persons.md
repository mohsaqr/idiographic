# Describe each person's series

One row per person per variable: how much data they contributed, where
they sit, how much they move, and how strongly each occasion carries
into the next.

## Usage

``` r
describe_persons(
  data,
  id,
  vars = NULL,
  time = NULL,
  subject = NULL,
  detail = c("basic", "full"),
  pac_quantile = 0.9,
  pac_cutoff = NULL,
  pac_direction = c("absolute", "increase", "decrease"),
  variable = NULL,
  sort_by = NULL,
  decreasing = FALSE,
  n = NULL
)
```

## Arguments

- data:

  Data frame of repeated measures.

- id:

  Person/unit ID column.

- vars:

  Columns to describe (any
  [`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md)
  selector). Defaults to every numeric column other than `id` and
  `time`.

- time:

  Optional ordering column. Supply it: without it, "successive" means
  the order the rows happen to be in.

- subject:

  Optional person(s) to describe. Defaults to everyone.

- detail:

  `"basic"` (the default) or `"full"`, which adds distribution shape,
  floor/ceiling occupancy, the probability of acute change, the person's
  linear trend, and the longest run of identical consecutive values.

- pac_quantile:

  Quantile of the pooled successive changes that defines an "acute" one.
  The convention is 0.9.

- pac_cutoff:

  Use this change size instead of a quantile of the data. Supply it to
  reproduce a published cutoff, or to make `pac` comparable across
  datasets.

- pac_direction:

  Whether an acute change means any large change (`"absolute"`), or
  specifically a large rise or fall.

- variable:

  Optional variable(s) to keep.

- sort_by:

  Optional column of the result to sort by, e.g. `"rmssd"`.

- decreasing:

  Sort order when `sort_by` is supplied.

- n:

  Optional number of rows to keep.

## Value

A `data.frame` of one row per person per variable, with class
`idiographic_descriptives`.

## Details

- `n`, `missing`:

  Usable and missing occasions – the compliance question, asked per
  person rather than for the sample as a whole.

- `mean`, `sd`:

  Level and overall dispersion.

- `rmssd`:

  Root mean square successive difference: the average
  occasion-to-occasion *change*. This is a different quantity from `sd`,
  and the pair is more informative than either alone – a slow drift
  gives a large `sd` with a small `rmssd`, and rapid oscillation gives
  the reverse.

- `autocor`:

  Lag-1 autocorrelation, the usual measure of inertia or carry-over: how
  much of where a person is now is explained by where they just were.

- `pac`:

  Probability of acute change (`detail = "full"`): how often this
  person's occasion-to-occasion change clears a bar set by the whole
  sample – by default the 90th percentile of everyone's changes. `rmssd`
  says how *large* the changes are and is dominated by a few big swings;
  `pac` says how *often* a large one happens and is not. Jahng, Wood and
  Trull (2008) recommend the pair together. Being sample-relative, `pac`
  is not comparable across datasets unless `pac_cutoff` is supplied.

- `span`, `gap_median`, `gap_max`:

  Only when `time` is given. How long the person was observed and how
  far apart their occasions were. Worth reading before trusting any lag:
  `gap_max` far above `gap_median` means "the previous occasion" is not
  a constant amount of time.

Successive differences and the autocorrelation are computed on
**adjacent occasions in time order within each person**, using only
pairs where both values are present. They are never taken across a
person boundary.

## Examples

``` r
describe_persons(srl, "name", time = "day", vars = c("effort", "efficacy"))
#> PERSON DESCRIPTIVES
#>   Grouping    name
#>   Time        day
#>   People      36
#>   Variables   2
#> 
#>   subject   variable     n   miss     mean   median       sd      min       max    rmssd   autocor      span   gap_median   gap_max
#> -----------------------------------------------------------------------------------------------------------------------------------
#>   Aisha     efficacy   156      0   56.919   61.765   21.034    0.000   100.000   26.881     0.169   155.000        1.000     1.000
#>   Alice     efficacy   156      0   35.761   36.364   20.614    0.000   100.000   28.790     0.024   155.000        1.000     1.000
#>   Anika     efficacy   156      0   50.099   47.692   19.373    0.000   100.000   28.656    -0.124   155.000        1.000     1.000
#>   Astrid    efficacy   156      0   72.401   78.378   20.078   10.811   100.000   28.496    -0.008   155.000        1.000     1.000
#>   Bjorn     efficacy   156      0   52.707   51.852   21.803    3.704   100.000   30.443     0.023   155.000        1.000     1.000
#>   Bob       efficacy   154      2   78.219   77.108   16.717    0.000   100.000   23.209     0.028   155.000        1.000     1.000
#>   Charlie   efficacy   156      0   46.239   46.667   17.767    0.000   100.000   25.857    -0.061   155.000        1.000     1.000
#>   Diana     efficacy   156      0   86.699   90.000   14.696    0.000   100.000   21.459    -0.066   155.000        1.000     1.000
#>   Erik      efficacy   156      0   28.050   27.586   27.530    0.000   100.000   39.069    -0.014   155.000        1.000     1.000
#>   Eve       efficacy   156      0   49.222   52.459   31.279    0.000   100.000   45.673    -0.076   155.000        1.000     1.000
#>   Fatima    efficacy   154      2   67.418   70.588   17.420    0.000   100.000   26.882    -0.187   155.000        1.000     1.000
#>   Frank     efficacy   156      0   61.311   61.458   15.797   16.667   100.000   23.334    -0.095   155.000        1.000     1.000
#> 
#>   ... 60 more rows.
#> 
#>   sd    = overall spread;  rmssd = occasion-to-occasion change
#>   autocor = lag-1 carry-over (inertia)

# One person, or the most volatile few -- without reaching into the result.
describe_persons(srl, "name", time = "day", subject = "Aisha")
#> PERSON DESCRIPTIVES
#>   Grouping    name
#>   Time        day
#>   People      1
#>   Variables   9
#> 
#>   subject   variable       n   miss     mean   median       sd     min       max    rmssd   autocor      span   gap_median   gap_max
#> ------------------------------------------------------------------------------------------------------------------------------------
#>   Aisha     control      156      0   52.389   51.515   25.507   0.000   100.000   35.298     0.031   155.000        1.000     1.000
#>   Aisha     efficacy     156      0   56.919   61.765   21.034   0.000   100.000   26.881     0.169   155.000        1.000     1.000
#>   Aisha     effort       156      0   77.646   82.540   18.080   0.000   100.000   23.724     0.132   155.000        1.000     1.000
#>   Aisha     help         156      0   48.244   49.000   18.839   0.000    88.000   28.131    -0.124   155.000        1.000     1.000
#>   Aisha     monitoring   156      0   25.287   18.421   24.259   0.000   100.000   33.391     0.052   155.000        1.000     1.000
#>   Aisha     organizing   156      0   61.270   69.355   27.941   0.000   100.000   38.844     0.003   155.000        1.000     1.000
#>   Aisha     planning     156      0   60.795   63.636   21.219   0.000    95.455   29.409     0.012   155.000        1.000     1.000
#>   Aisha     social       156      0   55.753   56.250   20.827   0.000   100.000   27.481     0.124   155.000        1.000     1.000
#>   Aisha     value        156      0   60.986   63.889   20.730   5.556   100.000   26.280     0.194   155.000        1.000     1.000
#> 
#>   sd    = overall spread;  rmssd = occasion-to-occasion change
#>   autocor = lag-1 carry-over (inertia)
describe_persons(srl, "name", time = "day", variable = "effort",
                 sort_by = "rmssd", decreasing = TRUE, n = 5)
#> PERSON DESCRIPTIVES
#>   Grouping    name
#>   Time        day
#>   People      5
#>   Variables   1
#> 
#>   subject   variable     n   miss     mean   median       sd     min       max    rmssd   autocor      span   gap_median   gap_max
#> ----------------------------------------------------------------------------------------------------------------------------------
#>   Karin     effort     156      0   61.176   73.913   34.061   0.000   100.000   48.061     0.001   155.000        1.000     1.000
#>   Erik      effort     156      0   42.330   47.368   35.159   0.000   100.000   46.286     0.126   155.000        1.000     1.000
#>   Lars      effort     156      0   50.701   53.488   31.961   0.000   100.000   43.756     0.059   155.000        1.000     1.000
#>   Frank     effort     156      0   44.409   37.037   28.913   0.000   100.000   43.589    -0.140   155.000        1.000     1.000
#>   Hiroshi   effort     156      0   23.449   10.000   26.630   0.000   100.000   38.260    -0.066   155.000        1.000     1.000
#> 
#>   sd    = overall spread;  rmssd = occasion-to-occasion change
#>   autocor = lag-1 carry-over (inertia)
```
