# Self-regulated learning intensive longitudinal data (Chapter 20)

The self-regulated learning (SRL) experience-sampling data used in the
Learning Analytics Methods book, Chapter 20 (Vector Autoregression).
Each of 36 students reported nine self-regulated-learning indicators
once per study occasion for 156 occasions, giving a balanced
person-by-time panel suitable for the idiographic time-series methods in
this package.

## Usage

``` r
srl
```

## Format

A `data.frame` with 5616 rows and 11 columns:

- name:

  Student name (36 unique students).

- day:

  Within-person occasion index, 1-156.

- efficacy:

  Self-efficacy.

- value:

  Task value.

- planning:

  Planning.

- monitoring:

  Monitoring.

- effort:

  Effort regulation.

- control:

  Control of learning.

- help:

  Help seeking.

- social:

  Social support.

- organizing:

  Organizing.

## Source

Learning Analytics Methods, Book 2, Chapter 20 (VAR):
<https://lamethods.org/book2/chapters/ch20-var/ch20-var.html>. Original
data: <https://github.com/lamethods/data2/raw/main/srl/srl.RDS>.

## Details

The columns have already been tidied for modelling: rows are ordered by
`name` then `day`, and `day` is a within-person occasion index (1-156)
you can pass as the `time` argument to
[`build_usem()`](https://saqr.me/idiographic/reference/build_usem.md)
and
[`build_gimme()`](https://saqr.me/idiographic/reference/build_gimme.md).
No further ordering, indexing, or column selection is needed before
fitting a model.

## Examples

``` r
data(srl)
summary(srl)
#>         name           day            efficacy          value       
#>  Length   :5616   Min.   :  1.00   Min.   :  0.00   Min.   :  0.00  
#>  N.unique :  36   1st Qu.: 39.75   1st Qu.: 35.38   1st Qu.: 38.46  
#>  N.blank  :   0   Median : 78.50   Median : 56.25   Median : 59.18  
#>  Min.nchar:   2   Mean   : 78.50   Mean   : 54.02   Mean   : 56.57  
#>  Max.nchar:   7   3rd Qu.:117.25   3rd Qu.: 75.00   3rd Qu.: 76.92  
#>                   Max.   :156.00   Max.   :100.00   Max.   :100.00  
#>                                    NAs    :6        NAs    :13      
#>     planning        monitoring         effort          control      
#>  Min.   :  0.00   Min.   :  0.00   Min.   :  0.00   Min.   :  0.00  
#>  1st Qu.: 37.50   1st Qu.: 23.91   1st Qu.: 40.98   1st Qu.: 28.21  
#>  Median : 58.62   Median : 52.00   Median : 62.69   Median : 55.81  
#>  Mean   : 56.83   Mean   : 49.09   Mean   : 58.99   Mean   : 52.75  
#>  3rd Qu.: 79.37   3rd Qu.: 73.26   3rd Qu.: 80.95   3rd Qu.: 77.27  
#>  Max.   :100.00   Max.   :100.00   Max.   :100.00   Max.   :100.00  
#>  NAs    :4        NAs    :5        NAs    :8        NAs    :10      
#>       help            social         organizing    
#>  Min.   :  0.00   Min.   :  0.00   Min.   :  0.00  
#>  1st Qu.: 42.86   1st Qu.: 34.04   1st Qu.: 37.04  
#>  Median : 66.27   Median : 60.00   Median : 57.69  
#>  Mean   : 62.10   Mean   : 56.54   Mean   : 55.49  
#>  3rd Qu.: 84.44   3rd Qu.: 81.67   3rd Qu.: 77.36  
#>  Max.   :100.00   Max.   :100.00   Max.   :100.00  
#>  NAs    :12       NAs    :69       NAs    :4       
head(srl)
#>    name day efficacy    value planning monitoring   effort  control help social
#> 1 Aisha   1 38.23529 58.33333  0.00000  34.210526 53.96825 39.39394   78   60.0
#> 2 Aisha   2 14.70588 47.22222 50.00000   7.894737 79.36508 45.45455   16   10.0
#> 3 Aisha   3 67.64706 52.77778 52.27273  19.736842 77.77778 39.39394   28   55.0
#> 4 Aisha   4 55.88235 63.88889 65.90909  22.368421 93.65079 42.42424   24   47.5
#> 5 Aisha   5 55.88235 36.11111 52.27273  22.368421 71.42857 57.57576   48   57.5
#> 6 Aisha   6 44.11765 61.11111 52.27273  57.894737 82.53968 42.42424   28   62.5
#>   organizing
#> 1   1.612903
#> 2  61.290323
#> 3  77.419355
#> 4  37.096774
#> 5  75.806452
#> 6  30.645161
```
