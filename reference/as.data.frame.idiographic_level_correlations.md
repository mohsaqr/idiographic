# Tidy tables from a within/between correlation comparison

Tidy tables from a within/between correlation comparison

## Usage

``` r
# S3 method for class 'idiographic_level_correlations'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("correlations", "summary"),
  ...
)
```

## Arguments

- x:

  A
  [`correlate_levels()`](https://pak.dynasite.org/idiographic/reference/correlate_levels.md)
  result.

- row.names, optional:

  Ignored.

- what:

  `"correlations"` (one row per correlation) or `"summary"` (one row per
  pair of variables, as
  [`summary()`](https://rdrr.io/r/base/summary.html)).

- ...:

  Ignored.

## Value

A `data.frame`: for `"correlations"`, one row per level, unit and pair
of variables (`level`, `unit`, `x`, `y`, `n`, `r`, ...), where the unit
is a person for `level = "within"` and an occasion for
`level = "between"`; for `"summary"`, one row per pair of variables
comparing the levels.

## Examples

``` r
lv <- correlate_levels(srl, id = "name", vars = c("efficacy", "effort"),
                       time = "day")
as.data.frame(lv)
#>       level    unit        x      y   n           r
#> 1    within   Aisha efficacy effort 156  0.35177224
#> 2    within   Alice efficacy effort 156  0.49080738
#> 3    within   Anika efficacy effort 156  0.43591241
#> 4    within  Astrid efficacy effort 156  0.18302877
#> 5    within   Bjorn efficacy effort 156  0.37561018
#> 6    within     Bob efficacy effort 154  0.41315722
#> 7    within Charlie efficacy effort 156  0.28354717
#> 8    within   Diana efficacy effort 156  0.06604477
#> 9    within    Erik efficacy effort 156  0.50419242
#> 10   within     Eve efficacy effort 156  0.54856464
#> 11   within  Fatima efficacy effort 154  0.25446951
#> 12   within   Frank efficacy effort 156  0.16823826
#> 13   within   Freja efficacy effort 156  0.05782032
#> 14   within   Grace efficacy effort 156  0.14133150
#> 15   within  Hassan efficacy effort 156  0.24346469
#> 16   within   Heidi efficacy effort 156  0.32622012
#> 17   within Hiroshi efficacy effort 156  0.83653831
#> 18   within  Ingrid efficacy effort 156  0.07433183
#> 19   within    Ivan efficacy effort 156  0.55888392
#> 20   within    Judy efficacy effort 156  0.37320651
#> 21   within   Karin efficacy effort 156  0.84062064
#> 22   within    Lars efficacy effort 156  0.86667481
#> 23   within   Layla efficacy effort 152  0.36564114
#> 24   within      Li efficacy effort 156  0.39768035
#> 25   within     Liv efficacy effort 156  0.76749940
#> 26   within     Mei efficacy effort 156  0.24598665
#> 27   within    Nils efficacy effort 156  0.55433552
#> 28   within    Noor efficacy effort 154  0.29812774
#> 29   within    Omar efficacy effort 156  0.62536246
#> 30   within    Ravi efficacy effort 156 -0.33079469
#> 31   within  Saanvi efficacy effort 156  0.23397998
#> 32   within  Sakura efficacy effort 156  0.34234341
#> 33   within    Sven efficacy effort 156  0.37311706
#> 34   within  Takumi efficacy effort 156  0.04818494
#> 35   within    Yuki efficacy effort 156  0.22224205
#> 36   within    Zain efficacy effort 156  0.55765408
#> 37  between       1 efficacy effort  36  0.58351961
#> 38  between       2 efficacy effort  36  0.42097565
#> 39  between       3 efficacy effort  35  0.38312153
#> 40  between       4 efficacy effort  36  0.57467935
#> 41  between       5 efficacy effort  36  0.65407978
#> 42  between       6 efficacy effort  36  0.12053870
#> 43  between       7 efficacy effort  36  0.46867549
#> 44  between       8 efficacy effort  36  0.38068715
#> 45  between       9 efficacy effort  36  0.36307680
#> 46  between      10 efficacy effort  36  0.30799466
#> 47  between      11 efficacy effort  36  0.45042515
#> 48  between      12 efficacy effort  36  0.78224765
#> 49  between      13 efficacy effort  36  0.52304293
#> 50  between      14 efficacy effort  36  0.42781669
#> 51  between      15 efficacy effort  36  0.71777985
#> 52  between      16 efficacy effort  36  0.49941791
#> 53  between      17 efficacy effort  36  0.39351549
#> 54  between      18 efficacy effort  36  0.36880444
#> 55  between      19 efficacy effort  36  0.40223541
#> 56  between      20 efficacy effort  36  0.56554390
#> 57  between      21 efficacy effort  36  0.75465349
#> 58  between      22 efficacy effort  36  0.62867112
#> 59  between      23 efficacy effort  36  0.57752065
#> 60  between      24 efficacy effort  35  0.48497756
#> 61  between      25 efficacy effort  36  0.61202658
#> 62  between      26 efficacy effort  36  0.54221526
#> 63  between      27 efficacy effort  36  0.19140124
#> 64  between      28 efficacy effort  36  0.40691000
#> 65  between      29 efficacy effort  36  0.29582468
#> 66  between      30 efficacy effort  36  0.50089632
#> 67  between      31 efficacy effort  36  0.57390040
#> 68  between      32 efficacy effort  36  0.67770904
#> 69  between      33 efficacy effort  36  0.50184122
#> 70  between      34 efficacy effort  36  0.46042409
#> 71  between      35 efficacy effort  36  0.47310149
#> 72  between      36 efficacy effort  36  0.62350041
#> 73  between      37 efficacy effort  36  0.65657144
#> 74  between      38 efficacy effort  35  0.42740440
#> 75  between      39 efficacy effort  36  0.50224951
#> 76  between      40 efficacy effort  36  0.42443748
#> 77  between      41 efficacy effort  36  0.59924227
#> 78  between      42 efficacy effort  36  0.29872547
#> 79  between      43 efficacy effort  36  0.42100337
#> 80  between      44 efficacy effort  36  0.53746074
#> 81  between      45 efficacy effort  35  0.53970822
#> 82  between      46 efficacy effort  36  0.71670229
#> 83  between      47 efficacy effort  36  0.40863664
#> 84  between      48 efficacy effort  36  0.63504018
#> 85  between      49 efficacy effort  36  0.43569394
#> 86  between      50 efficacy effort  36  0.42913977
#> 87  between      51 efficacy effort  36  0.63299084
#> 88  between      52 efficacy effort  36  0.30595873
#> 89  between      53 efficacy effort  36  0.38556512
#> 90  between      54 efficacy effort  36  0.58959293
#> 91  between      55 efficacy effort  36  0.42202606
#> 92  between      56 efficacy effort  36  0.64259600
#> 93  between      57 efficacy effort  36  0.68238551
#> 94  between      58 efficacy effort  35  0.40624729
#> 95  between      59 efficacy effort  36  0.18517846
#> 96  between      60 efficacy effort  35  0.20406868
#> 97  between      61 efficacy effort  36  0.41450610
#> 98  between      62 efficacy effort  36  0.41120983
#> 99  between      63 efficacy effort  36  0.77356059
#> 100 between      64 efficacy effort  35  0.53169402
#> 101 between      65 efficacy effort  36  0.53123051
#> 102 between      66 efficacy effort  36  0.34949285
#> 103 between      67 efficacy effort  36  0.34469077
#> 104 between      68 efficacy effort  36  0.19106742
#> 105 between      69 efficacy effort  36  0.43021357
#> 106 between      70 efficacy effort  36  0.38394788
#> 107 between      71 efficacy effort  36  0.45006908
#> 108 between      72 efficacy effort  36  0.60491854
#> 109 between      73 efficacy effort  36  0.51754830
#> 110 between      74 efficacy effort  36  0.47059261
#> 111 between      75 efficacy effort  36  0.27482416
#> 112 between      76 efficacy effort  36  0.51198224
#> 113 between      77 efficacy effort  36  0.33243916
#> 114 between      78 efficacy effort  36  0.40475872
#> 115 between      79 efficacy effort  36  0.44198824
#> 116 between      80 efficacy effort  36  0.63380360
#> 117 between      81 efficacy effort  36  0.41386200
#> 118 between      82 efficacy effort  36  0.33497364
#> 119 between      83 efficacy effort  36  0.58412900
#> 120 between      84 efficacy effort  36  0.67072661
#> 121 between      85 efficacy effort  36  0.60295396
#> 122 between      86 efficacy effort  36  0.51134649
#> 123 between      87 efficacy effort  36  0.53191110
#> 124 between      88 efficacy effort  36  0.44470323
#> 125 between      89 efficacy effort  36  0.35520411
#> 126 between      90 efficacy effort  36  0.44657125
#> 127 between      91 efficacy effort  36  0.52267526
#> 128 between      92 efficacy effort  36  0.45528487
#> 129 between      93 efficacy effort  36  0.58833826
#> 130 between      94 efficacy effort  36  0.38157797
#> 131 between      95 efficacy effort  36  0.48651261
#> 132 between      96 efficacy effort  36  0.64832408
#> 133 between      97 efficacy effort  36  0.75169546
#> 134 between      98 efficacy effort  36  0.70649228
#> 135 between      99 efficacy effort  36  0.46240138
#> 136 between     100 efficacy effort  36  0.65040019
#> 137 between     101 efficacy effort  36  0.51189664
#> 138 between     102 efficacy effort  36  0.58797595
#> 139 between     103 efficacy effort  36  0.50790067
#> 140 between     104 efficacy effort  36  0.31327726
#> 141 between     105 efficacy effort  36  0.55952641
#> 142 between     106 efficacy effort  36  0.39447252
#> 143 between     107 efficacy effort  36  0.52443596
#> 144 between     108 efficacy effort  36  0.31072688
#> 145 between     109 efficacy effort  36  0.27613128
#> 146 between     110 efficacy effort  36  0.53132613
#> 147 between     111 efficacy effort  36  0.51751416
#> 148 between     112 efficacy effort  36  0.52473580
#> 149 between     113 efficacy effort  36  0.29662932
#> 150 between     114 efficacy effort  36  0.49367100
#> 151 between     115 efficacy effort  36  0.69057480
#> 152 between     116 efficacy effort  36  0.52207994
#> 153 between     117 efficacy effort  35  0.50758534
#> 154 between     118 efficacy effort  36  0.50721291
#> 155 between     119 efficacy effort  36  0.22516437
#> 156 between     120 efficacy effort  36  0.32890093
#> 157 between     121 efficacy effort  36  0.55298846
#> 158 between     122 efficacy effort  36  0.38656090
#> 159 between     123 efficacy effort  36  0.72495308
#> 160 between     124 efficacy effort  36  0.62498771
#> 161 between     125 efficacy effort  36  0.64582012
#> 162 between     126 efficacy effort  36  0.57456128
#> 163 between     127 efficacy effort  36  0.41294166
#> 164 between     128 efficacy effort  36  0.71976222
#> 165 between     129 efficacy effort  36  0.67742873
#> 166 between     130 efficacy effort  36  0.26790939
#> 167 between     131 efficacy effort  36  0.78289862
#> 168 between     132 efficacy effort  36  0.43752383
#> 169 between     133 efficacy effort  36  0.62566355
#> 170 between     134 efficacy effort  36  0.55356790
#> 171 between     135 efficacy effort  36  0.66366250
#> 172 between     136 efficacy effort  36  0.49911019
#> 173 between     137 efficacy effort  36  0.47945496
#> 174 between     138 efficacy effort  35  0.73232229
#> 175 between     139 efficacy effort  36  0.53073465
#> 176 between     140 efficacy effort  36  0.63943941
#> 177 between     141 efficacy effort  36  0.63891851
#> 178 between     142 efficacy effort  36  0.47893204
#> 179 between     143 efficacy effort  36  0.50026704
#> 180 between     144 efficacy effort  36  0.36000865
#> 181 between     145 efficacy effort  36  0.61163137
#> 182 between     146 efficacy effort  36  0.59988685
#> 183 between     147 efficacy effort  36  0.67249840
#> 184 between     148 efficacy effort  36  0.66644957
#> 185 between     149 efficacy effort  35  0.53777190
#> 186 between     150 efficacy effort  36  0.59372766
#> 187 between     151 efficacy effort  36  0.66950289
#> 188 between     152 efficacy effort  36  0.44113807
#> 189 between     153 efficacy effort  36  0.52978294
#> 190 between     154 efficacy effort  36  0.61889437
#> 191 between     155 efficacy effort  36  0.51701700
#> 192 between     156 efficacy effort  36  0.70413306
as.data.frame(lv, what = "summary")
#>          x      y n_within mean_within median_within sd_within n_between
#> 1 efficacy effort       36   0.3637722     0.3587067 0.2498384       156
#>   mean_between median_between sd_between mean_difference sd_ratio
#> 1    0.5034717      0.5096236  0.1373181      -0.1396996 1.819413
```
