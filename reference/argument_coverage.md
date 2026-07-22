# Argument-by-argument validation coverage

Builds a tidy, executable ledger from the actual formals of every
registered entry point. Each argument is classified according to the
strongest honest evidence contract available for that method: direct
oracle/engine equality, frozen statistical fixtures, recovery/internal
validation, delegated forwarding, a supported extension, or an explicit
rejection boundary. Consequently a newly added formal cannot silently
disappear from the audit: package tests require every current formal to
occur exactly once here.

## Usage

``` r
argument_coverage(method = NULL)
```

## Arguments

- method:

  Optional registered method name or alias. `NULL` returns all built-in
  and currently registered methods.

## Value

A data frame with one row per public method argument.

## Examples

``` r
argument_coverage()
#>                    method      kind             argument
#> 161                 gimme estimator                 data
#> 162                 gimme estimator                 vars
#> 163                 gimme estimator                   id
#> 165                 gimme estimator                  day
#> 166                 gimme estimator                 beep
#> 167                 gimme estimator              min_obs
#> 168                 gimme estimator              subject
#> 182                 gimme estimator                 seed
#> 170                 gimme estimator          standardize
#> 164                 gimme estimator                 time
#> 180                 gimme estimator           cfi_cutoff
#> 177                 gimme estimator         rmsea_cutoff
#> 178                 gimme estimator          srmr_cutoff
#> 173                 gimme estimator                paths
#> 174                 gimme estimator            exogenous
#> 169                 gimme estimator                   ar
#> 171                 gimme estimator          groupcutoff
#> 172                 gimme estimator            subcutoff
#> 175                 gimme estimator               hybrid
#> 176                 gimme estimator                  VAR
#> 179                 gimme estimator          nnfi_cutoff
#> 181                 gimme estimator          n_excellent
#> 183                 gimme estimator        group_correct
#> 184                 gimme estimator        indiv_correct
#> 185                 gimme estimator                alpha
#> 186                 gimme estimator            stop_crit
#> 187                 gimme estimator             subgroup
#> 188                 gimme estimator              outcome
#> 189                 gimme estimator            conv_vars
#> 190                 gimme estimator            mult_vars
#> 191                 gimme estimator             lv_model
#> 192                 gimme estimator     lasso_model_crit
#> 193                 gimme estimator             ms_allow
#> 194                 gimme estimator              ordered
#> 195                 gimme estimator      dir_prop_cutoff
#> 196                 gimme estimator                  out
#> 197                 gimme estimator                  sep
#> 198                 gimme estimator               header
#> 199                 gimme estimator                 plot
#> 200                 gimme estimator          sub_feature
#> 201                 gimme estimator           sub_method
#> 202                 gimme estimator       sub_sim_thresh
#> 203                 gimme estimator     confirm_subgroup
#> 204                 gimme estimator          conv_length
#> 205                 gimme estimator        conv_interval
#> 206                 gimme estimator     mean_center_mult
#> 207                 gimme estimator              diagnos
#> 208                 gimme estimator               ms_tol
#> 209                 gimme estimator         lv_estimator
#> 210                 gimme estimator            lv_scores
#> 211                 gimme estimator      lv_miiv_scaling
#> 212                 gimme estimator   lv_final_estimator
#> 35          graphical_var estimator                 data
#> 36          graphical_var estimator                 vars
#> 37          graphical_var estimator                   id
#> 38          graphical_var estimator                  day
#> 39          graphical_var estimator                 beep
#> 40          graphical_var estimator                 lags
#> 43          graphical_var estimator                scale
#> 44          graphical_var estimator        center_within
#> 55          graphical_var estimator      delete_missings
#> 60          graphical_var estimator              min_obs
#> 61          graphical_var estimator              subject
#> 59          graphical_var estimator              verbose
#> 41          graphical_var estimator             n_lambda
#> 42          graphical_var estimator                gamma
#> 45          graphical_var estimator     lambda_min_ratio
#> 46          graphical_var estimator     lambda_min_kappa
#> 47          graphical_var estimator      lambda_min_beta
#> 48          graphical_var estimator    penalize_diagonal
#> 49          graphical_var estimator          lambda_beta
#> 50          graphical_var estimator         lambda_kappa
#> 51          graphical_var estimator  regularize_mat_beta
#> 52          graphical_var estimator regularize_mat_kappa
#> 53          graphical_var estimator             maxit_in
#> 54          graphical_var estimator            maxit_out
#> 56          graphical_var estimator           likelihood
#> 57          graphical_var estimator             ebic_tol
#> 58          graphical_var estimator                mimic
#> 62     graphical_var_each estimator                 data
#> 63     graphical_var_each estimator                 vars
#> 64     graphical_var_each estimator                   id
#> 65     graphical_var_each estimator                  day
#> 66     graphical_var_each estimator                 beep
#> 67     graphical_var_each estimator              min_obs
#> 68     graphical_var_each estimator                  ...
#> 240                    ml estimator                 data
#> 243                    ml estimator                   id
#> 244                    ml estimator                  day
#> 245                    ml estimator                 beep
#> 261                    ml estimator                  ...
#> 248                    ml estimator            estimator
#> 259                    ml estimator          standardize
#> 254                    ml estimator                alpha
#> 241                    ml estimator              outcome
#> 260                    ml estimator            keep_fits
#> 242                    ml estimator           predictors
#> 246                    ml estimator                 task
#> 247                    ml estimator                model
#> 249                    ml estimator              compare
#> 250                    ml estimator            test_prop
#> 251                    ml estimator            min_train
#> 252                    ml estimator             min_test
#> 253                    ml estimator               lambda
#> 255                    ml estimator                    k
#> 256                    ml estimator         n_components
#> 257                    ml estimator             max_iter
#> 258                    ml estimator                  tol
#> 69                  mlvar estimator                 data
#> 70                  mlvar estimator                 vars
#> 71                  mlvar estimator                   id
#> 72                  mlvar estimator                  day
#> 73                  mlvar estimator                 beep
#> 74                  mlvar estimator                 lags
#> 79                  mlvar estimator                scale
#> 85                  mlvar estimator              min_obs
#> 86                  mlvar estimator              subject
#> 95                  mlvar estimator                  ...
#> 82                  mlvar estimator              verbose
#> 75                  mlvar estimator            estimator
#> 76                  mlvar estimator             temporal
#> 77                  mlvar estimator      contemporaneous
#> 78                  mlvar estimator                   AR
#> 80                  mlvar estimator          scaleWithin
#> 81                  mlvar estimator               nCores
#> 83                  mlvar estimator                  lag
#> 84                  mlvar estimator          standardize
#> 87                  mlvar estimator               engine
#> 88                  mlvar estimator     standardize_mode
#> 89                  mlvar estimator              missing
#> 90                  mlvar estimator      compare_to_lags
#> 91                  mlvar estimator           true_means
#> 92                  mlvar estimator              detrend
#> 93                  mlvar estimator                na_rm
#> 94                  mlvar estimator           orthogonal
#> 96            mlvar_bayes estimator                 data
#> 97            mlvar_bayes estimator                 vars
#> 98            mlvar_bayes estimator                   id
#> 99            mlvar_bayes estimator                  day
#> 100           mlvar_bayes estimator                 beep
#> 101           mlvar_bayes estimator                 lags
#> 105           mlvar_bayes estimator                scale
#> 114           mlvar_bayes estimator              min_obs
#> 115           mlvar_bayes estimator              subject
#> 109           mlvar_bayes estimator               n_iter
#> 110           mlvar_bayes estimator             n_burnin
#> 111           mlvar_bayes estimator             n_chains
#> 112           mlvar_bayes estimator                 thin
#> 113           mlvar_bayes estimator                 seed
#> 116           mlvar_bayes estimator              verbose
#> 102           mlvar_bayes estimator             temporal
#> 103           mlvar_bayes estimator      contemporaneous
#> 106           mlvar_bayes estimator          scaleWithin
#> 104           mlvar_bayes estimator             residual
#> 107           mlvar_bayes estimator            tinterval
#> 108           mlvar_bayes estimator               impute
#> 117           mlvar_mplus estimator                 data
#> 118           mlvar_mplus estimator                 vars
#> 119           mlvar_mplus estimator                   id
#> 120           mlvar_mplus estimator                  day
#> 121           mlvar_mplus estimator                 beep
#> 122           mlvar_mplus estimator                 lags
#> 126           mlvar_mplus estimator                scale
#> 133           mlvar_mplus estimator              min_obs
#> 134           mlvar_mplus estimator              subject
#> 137           mlvar_mplus estimator                  ...
#> 136           mlvar_mplus estimator              verbose
#> 123           mlvar_mplus estimator             temporal
#> 124           mlvar_mplus estimator      contemporaneous
#> 127           mlvar_mplus estimator          scaleWithin
#> 125           mlvar_mplus estimator               nCores
#> 128           mlvar_mplus estimator            MplusSave
#> 129           mlvar_mplus estimator            MplusName
#> 130           mlvar_mplus estimator           iterations
#> 131           mlvar_mplus estimator               chains
#> 132           mlvar_mplus estimator                signs
#> 135           mlvar_mplus estimator              workdir
#> 226 rolling_graphical_var estimator                 data
#> 227 rolling_graphical_var estimator                 vars
#> 228 rolling_graphical_var estimator                   id
#> 229 rolling_graphical_var estimator                  day
#> 230 rolling_graphical_var estimator                 beep
#> 233 rolling_graphical_var estimator                scale
#> 234 rolling_graphical_var estimator        center_within
#> 235 rolling_graphical_var estimator      delete_missings
#> 236 rolling_graphical_var estimator              min_obs
#> 237 rolling_graphical_var estimator              subject
#> 239 rolling_graphical_var estimator                  ...
#> 231 rolling_graphical_var estimator          window_size
#> 232 rolling_graphical_var estimator                 step
#> 238 rolling_graphical_var estimator            keep_fits
#> 213           rolling_var estimator                 data
#> 214           rolling_var estimator                 vars
#> 215           rolling_var estimator                   id
#> 216           rolling_var estimator                  day
#> 217           rolling_var estimator                 beep
#> 220           rolling_var estimator                scale
#> 221           rolling_var estimator        center_within
#> 222           rolling_var estimator      delete_missings
#> 223           rolling_var estimator              min_obs
#> 224           rolling_var estimator              subject
#> 218           rolling_var estimator          window_size
#> 219           rolling_var estimator                 step
#> 225           rolling_var estimator            keep_fits
#> 138                  usem estimator                 data
#> 139                  usem estimator                 vars
#> 140                  usem estimator                   id
#> 142                  usem estimator                  day
#> 143                  usem estimator                 beep
#> 144                  usem estimator              min_obs
#> 145                  usem estimator              subject
#> 160                  usem estimator                 seed
#> 159                  usem estimator            estimator
#> 146                  usem estimator             temporal
#> 147                  usem estimator      contemporaneous
#> 158                  usem estimator          standardize
#> 141                  usem estimator                 time
#> 148                  usem estimator         residual_cov
#> 149                  usem estimator                 trim
#> 150                  usem estimator           trim_alpha
#> 151                  usem estimator    trim_fit_criteria
#> 152                  usem estimator           cfi_cutoff
#> 153                  usem estimator           tli_cutoff
#> 154                  usem estimator         rmsea_cutoff
#> 155                  usem estimator          srmr_cutoff
#> 156                  usem estimator                paths
#> 157                  usem estimator            exogenous
#> 1                     var estimator                 data
#> 2                     var estimator                 vars
#> 3                     var estimator                   id
#> 4                     var estimator                  day
#> 5                     var estimator                 beep
#> 6                     var estimator                 lags
#> 7                     var estimator                scale
#> 8                     var estimator        center_within
#> 9                     var estimator      delete_missings
#> 10                    var estimator              min_obs
#> 11                    var estimator              subject
#> 19              var_bayes estimator                 data
#> 20              var_bayes estimator                 vars
#> 21              var_bayes estimator                   id
#> 22              var_bayes estimator                  day
#> 23              var_bayes estimator                 beep
#> 24              var_bayes estimator                 lags
#> 25              var_bayes estimator                scale
#> 26              var_bayes estimator        center_within
#> 32              var_bayes estimator              min_obs
#> 33              var_bayes estimator              subject
#> 27              var_bayes estimator               n_iter
#> 28              var_bayes estimator             n_burnin
#> 29              var_bayes estimator             n_chains
#> 30              var_bayes estimator                 thin
#> 31              var_bayes estimator                 seed
#> 34              var_bayes estimator              verbose
#> 12               var_each estimator                 data
#> 13               var_each estimator                 vars
#> 14               var_each estimator                   id
#> 15               var_each estimator                  day
#> 16               var_each estimator                 beep
#> 17               var_each estimator              min_obs
#> 18               var_each estimator                  ...
#> 292               compare  workflow                 data
#> 293               compare  workflow                 vars
#> 295               compare  workflow                   id
#> 296               compare  workflow                  day
#> 297               compare  workflow                 beep
#> 299               compare  workflow            keep_fits
#> 294               compare  workflow           estimators
#> 298               compare  workflow       estimator_args
#> 300              forecast  workflow                 data
#> 301              forecast  workflow                 vars
#> 303              forecast  workflow                   id
#> 304              forecast  workflow                  day
#> 305              forecast  workflow                 beep
#> 311              forecast  workflow                scale
#> 312              forecast  workflow        center_within
#> 313              forecast  workflow      delete_missings
#> 315              forecast  workflow                  ...
#> 302              forecast  workflow            estimator
#> 308              forecast  workflow                 step
#> 314              forecast  workflow            keep_fits
#> 310              forecast  workflow           block_size
#> 306              forecast  workflow              initial
#> 307              forecast  workflow               assess
#> 309              forecast  workflow             n_splits
#> 262            preprocess  workflow                 data
#> 263            preprocess  workflow                 vars
#> 264            preprocess  workflow                   id
#> 265            preprocess  workflow                  day
#> 266            preprocess  workflow                 beep
#> 267            preprocess  workflow                scale
#> 268            preprocess  workflow        center_within
#> 271            preprocess  workflow      delete_missings
#> 272            preprocess  workflow              min_obs
#> 273            preprocess  workflow              subject
#> 269            preprocess  workflow              detrend
#> 270            preprocess  workflow               checks
#> 274            preprocess  workflow          trend_alpha
#> 275            preprocess  workflow         ar_threshold
#> 276            preprocess  workflow mean_shift_threshold
#> 277            preprocess  workflow   sd_ratio_threshold
#> 278            preprocess  workflow   unit_root_t_cutoff
#> 279             stability  workflow                 data
#> 280             stability  workflow                 vars
#> 282             stability  workflow                   id
#> 283             stability  workflow                  day
#> 284             stability  workflow                 beep
#> 291             stability  workflow                  ...
#> 289             stability  workflow                 seed
#> 281             stability  workflow            estimator
#> 290             stability  workflow            keep_fits
#> 285             stability  workflow          n_resamples
#> 286             stability  workflow             resample
#> 287             stability  workflow           block_size
#> 288             stability  workflow            threshold
#>                         status                       reference
#> 161    validated_oracle_matrix               gimme::gimme 10.0
#> 162    validated_oracle_matrix               gimme::gimme 10.0
#> 163    validated_oracle_matrix               gimme::gimme 10.0
#> 165    validated_oracle_matrix               gimme::gimme 10.0
#> 166    validated_oracle_matrix               gimme::gimme 10.0
#> 167    validated_oracle_matrix               gimme::gimme 10.0
#> 168    validated_oracle_matrix               gimme::gimme 10.0
#> 182    validated_oracle_matrix               gimme::gimme 10.0
#> 170    validated_oracle_matrix               gimme::gimme 10.0
#> 164    validated_oracle_matrix               gimme::gimme 10.0
#> 180    validated_oracle_matrix               gimme::gimme 10.0
#> 177    validated_oracle_matrix               gimme::gimme 10.0
#> 178    validated_oracle_matrix               gimme::gimme 10.0
#> 173    validated_oracle_matrix               gimme::gimme 10.0
#> 174    validated_oracle_matrix               gimme::gimme 10.0
#> 169 oracle_or_upstream_failure               gimme::gimme 10.0
#> 171    validated_oracle_matrix               gimme::gimme 10.0
#> 172  explicit_warning_boundary               gimme::gimme 10.0
#> 175    validated_oracle_matrix               gimme::gimme 10.0
#> 176    validated_oracle_matrix               gimme::gimme 10.0
#> 179    validated_oracle_matrix               gimme::gimme 10.0
#> 181    validated_oracle_matrix               gimme::gimme 10.0
#> 183    validated_oracle_matrix               gimme::gimme 10.0
#> 184    validated_oracle_matrix               gimme::gimme 10.0
#> 185    validated_oracle_matrix               gimme::gimme 10.0
#> 186    validated_oracle_matrix               gimme::gimme 10.0
#> 187         explicit_rejection               gimme::gimme 10.0
#> 188         explicit_rejection               gimme::gimme 10.0
#> 189         explicit_rejection               gimme::gimme 10.0
#> 190         explicit_rejection               gimme::gimme 10.0
#> 191         explicit_rejection               gimme::gimme 10.0
#> 192         explicit_rejection               gimme::gimme 10.0
#> 193         explicit_rejection               gimme::gimme 10.0
#> 194         explicit_rejection               gimme::gimme 10.0
#> 195         explicit_rejection               gimme::gimme 10.0
#> 196  explicit_warning_boundary               gimme::gimme 10.0
#> 197  explicit_warning_boundary               gimme::gimme 10.0
#> 198  explicit_warning_boundary               gimme::gimme 10.0
#> 199  explicit_warning_boundary               gimme::gimme 10.0
#> 200  explicit_warning_boundary               gimme::gimme 10.0
#> 201  explicit_warning_boundary               gimme::gimme 10.0
#> 202  explicit_warning_boundary               gimme::gimme 10.0
#> 203  explicit_warning_boundary               gimme::gimme 10.0
#> 204  explicit_warning_boundary               gimme::gimme 10.0
#> 205  explicit_warning_boundary               gimme::gimme 10.0
#> 206  explicit_warning_boundary               gimme::gimme 10.0
#> 207  explicit_warning_boundary               gimme::gimme 10.0
#> 208  explicit_warning_boundary               gimme::gimme 10.0
#> 209  explicit_warning_boundary               gimme::gimme 10.0
#> 210  explicit_warning_boundary               gimme::gimme 10.0
#> 211  explicit_warning_boundary               gimme::gimme 10.0
#> 212  explicit_warning_boundary               gimme::gimme 10.0
#> 35            validated_oracle      graphicalVAR::graphicalVAR
#> 36            validated_oracle      graphicalVAR::graphicalVAR
#> 37            validated_oracle      graphicalVAR::graphicalVAR
#> 38            validated_oracle      graphicalVAR::graphicalVAR
#> 39            validated_oracle      graphicalVAR::graphicalVAR
#> 40      validated_or_extension      graphicalVAR::graphicalVAR
#> 43            validated_oracle      graphicalVAR::graphicalVAR
#> 44            validated_oracle      graphicalVAR::graphicalVAR
#> 55            validated_oracle      graphicalVAR::graphicalVAR
#> 60          validated_behavior      graphicalVAR::graphicalVAR
#> 61          validated_behavior      graphicalVAR::graphicalVAR
#> 59          validated_behavior      graphicalVAR::graphicalVAR
#> 41      validated_or_extension      graphicalVAR::graphicalVAR
#> 42            validated_oracle      graphicalVAR::graphicalVAR
#> 45            validated_oracle      graphicalVAR::graphicalVAR
#> 46            validated_oracle      graphicalVAR::graphicalVAR
#> 47            validated_oracle      graphicalVAR::graphicalVAR
#> 48            validated_oracle      graphicalVAR::graphicalVAR
#> 49            validated_oracle      graphicalVAR::graphicalVAR
#> 50            validated_oracle      graphicalVAR::graphicalVAR
#> 51            validated_oracle      graphicalVAR::graphicalVAR
#> 52            validated_oracle      graphicalVAR::graphicalVAR
#> 53            validated_oracle      graphicalVAR::graphicalVAR
#> 54            validated_oracle      graphicalVAR::graphicalVAR
#> 56            validated_oracle      graphicalVAR::graphicalVAR
#> 57            validated_oracle      graphicalVAR::graphicalVAR
#> 58       validated_or_rejected      graphicalVAR::graphicalVAR
#> 62           validated_wrapper      graphicalVAR::graphicalVAR
#> 63           validated_wrapper      graphicalVAR::graphicalVAR
#> 64           validated_wrapper      graphicalVAR::graphicalVAR
#> 65           validated_wrapper      graphicalVAR::graphicalVAR
#> 66           validated_wrapper      graphicalVAR::graphicalVAR
#> 67           validated_wrapper      graphicalVAR::graphicalVAR
#> 68        validated_forwarding      graphicalVAR::graphicalVAR
#> 240           validated_native base-R engines and closed forms
#> 243           validated_native base-R engines and closed forms
#> 244           validated_native base-R engines and closed forms
#> 245           validated_native base-R engines and closed forms
#> 261           validated_native base-R engines and closed forms
#> 248           validated_native base-R engines and closed forms
#> 259           validated_native base-R engines and closed forms
#> 254           validated_native base-R engines and closed forms
#> 241           validated_native base-R engines and closed forms
#> 260           validated_native base-R engines and closed forms
#> 242           validated_native base-R engines and closed forms
#> 246           validated_native base-R engines and closed forms
#> 247           validated_native base-R engines and closed forms
#> 249           validated_native base-R engines and closed forms
#> 250           validated_native base-R engines and closed forms
#> 251           validated_native base-R engines and closed forms
#> 252           validated_native base-R engines and closed forms
#> 253           validated_native base-R engines and closed forms
#> 255           validated_native base-R engines and closed forms
#> 256           validated_native base-R engines and closed forms
#> 257           validated_native base-R engines and closed forms
#> 258           validated_native base-R engines and closed forms
#> 69            validated_oracle                    mlVAR::mlVAR
#> 70            validated_oracle                    mlVAR::mlVAR
#> 71            validated_oracle                    mlVAR::mlVAR
#> 72            validated_oracle                    mlVAR::mlVAR
#> 73            validated_oracle                    mlVAR::mlVAR
#> 74              mode_dependent                    mlVAR::mlVAR
#> 79            validated_oracle                    mlVAR::mlVAR
#> 85          validated_behavior                    mlVAR::mlVAR
#> 86          validated_behavior                    mlVAR::mlVAR
#> 95       validated_or_rejected                    mlVAR::mlVAR
#> 82          validated_behavior                    mlVAR::mlVAR
#> 75              mode_dependent                    mlVAR::mlVAR
#> 76              mode_dependent                    mlVAR::mlVAR
#> 77              mode_dependent                    mlVAR::mlVAR
#> 78            validated_oracle                    mlVAR::mlVAR
#> 80            validated_oracle                    mlVAR::mlVAR
#> 81            validated_oracle                    mlVAR::mlVAR
#> 83            validated_oracle                    mlVAR::mlVAR
#> 84            validated_oracle                    mlVAR::mlVAR
#> 87              mode_dependent                    mlVAR::mlVAR
#> 88            validated_oracle                    mlVAR::mlVAR
#> 89          validated_behavior                    mlVAR::mlVAR
#> 90            validated_oracle                    mlVAR::mlVAR
#> 91            validated_oracle                    mlVAR::mlVAR
#> 92            validated_oracle                    mlVAR::mlVAR
#> 93            validated_oracle                    mlVAR::mlVAR
#> 94            validated_oracle                    mlVAR::mlVAR
#> 96       validated_statistical                      Mplus DSEM
#> 97       validated_statistical                      Mplus DSEM
#> 98       validated_statistical                      Mplus DSEM
#> 99       validated_statistical                      Mplus DSEM
#> 100      validated_statistical                      Mplus DSEM
#> 101      validated_statistical                      Mplus DSEM
#> 105      validated_statistical                      Mplus DSEM
#> 114      validated_statistical                      Mplus DSEM
#> 115      validated_statistical                      Mplus DSEM
#> 109      validated_statistical                      Mplus DSEM
#> 110      validated_statistical                      Mplus DSEM
#> 111      validated_statistical                      Mplus DSEM
#> 112      validated_statistical                      Mplus DSEM
#> 113      validated_statistical                      Mplus DSEM
#> 116      validated_statistical                      Mplus DSEM
#> 102        fixture_or_recovery                      Mplus DSEM
#> 103      validated_statistical                      Mplus DSEM
#> 106      validated_statistical                      Mplus DSEM
#> 104        fixture_or_recovery                      Mplus DSEM
#> 107        fixture_or_recovery                      Mplus DSEM
#> 108        fixture_or_recovery                      Mplus DSEM
#> 117         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 118         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 119         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 120         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 121         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 122         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 126         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 133         validated_behavior mlVAR::mlVAR(estimator='Mplus')
#> 134         validated_behavior mlVAR::mlVAR(estimator='Mplus')
#> 137         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 136         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 123         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 124         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 127         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 125         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 128         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 129         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 130         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 131         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 132         delegated_contract mlVAR::mlVAR(estimator='Mplus')
#> 135         validated_behavior mlVAR::mlVAR(estimator='Mplus')
#> 226         validated_internal  idiographic::fit_graphical_var
#> 227         validated_internal  idiographic::fit_graphical_var
#> 228         validated_internal  idiographic::fit_graphical_var
#> 229         validated_internal  idiographic::fit_graphical_var
#> 230         validated_internal  idiographic::fit_graphical_var
#> 233         validated_internal  idiographic::fit_graphical_var
#> 234         validated_internal  idiographic::fit_graphical_var
#> 235         validated_internal  idiographic::fit_graphical_var
#> 236         validated_internal  idiographic::fit_graphical_var
#> 237         validated_internal  idiographic::fit_graphical_var
#> 239         validated_internal  idiographic::fit_graphical_var
#> 231         validated_internal  idiographic::fit_graphical_var
#> 232         validated_internal  idiographic::fit_graphical_var
#> 238         validated_internal  idiographic::fit_graphical_var
#> 213         validated_internal            idiographic::fit_var
#> 214         validated_internal            idiographic::fit_var
#> 215         validated_internal            idiographic::fit_var
#> 216         validated_internal            idiographic::fit_var
#> 217         validated_internal            idiographic::fit_var
#> 220         validated_internal            idiographic::fit_var
#> 221         validated_internal            idiographic::fit_var
#> 222         validated_internal            idiographic::fit_var
#> 223         validated_internal            idiographic::fit_var
#> 224         validated_internal            idiographic::fit_var
#> 218         validated_internal            idiographic::fit_var
#> 219         validated_internal            idiographic::fit_var
#> 225         validated_internal            idiographic::fit_var
#> 138           validated_engine                  lavaan::lavaan
#> 139           validated_engine                  lavaan::lavaan
#> 140           validated_engine                  lavaan::lavaan
#> 142           validated_engine                  lavaan::lavaan
#> 143           validated_engine                  lavaan::lavaan
#> 144           validated_engine                  lavaan::lavaan
#> 145           validated_engine                  lavaan::lavaan
#> 160           validated_engine                  lavaan::lavaan
#> 159           validated_engine                  lavaan::lavaan
#> 146           validated_engine                  lavaan::lavaan
#> 147           validated_engine                  lavaan::lavaan
#> 158           validated_engine                  lavaan::lavaan
#> 141           validated_engine                  lavaan::lavaan
#> 148           validated_engine                  lavaan::lavaan
#> 149        validated_extension                  lavaan::lavaan
#> 150        validated_extension                  lavaan::lavaan
#> 151        validated_extension                  lavaan::lavaan
#> 152        validated_extension                  lavaan::lavaan
#> 153        validated_extension                  lavaan::lavaan
#> 154        validated_extension                  lavaan::lavaan
#> 155        validated_extension                  lavaan::lavaan
#> 156           validated_engine                  lavaan::lavaan
#> 157           validated_engine                  lavaan::lavaan
#> 1             validated_engine                   stats::lm.fit
#> 2             validated_engine                   stats::lm.fit
#> 3             validated_engine                   stats::lm.fit
#> 4             validated_engine                   stats::lm.fit
#> 5             validated_engine                   stats::lm.fit
#> 6             validated_engine                   stats::lm.fit
#> 7             validated_engine                   stats::lm.fit
#> 8             validated_engine                   stats::lm.fit
#> 9             validated_engine                   stats::lm.fit
#> 10            validated_engine                   stats::lm.fit
#> 11            validated_engine                   stats::lm.fit
#> 19       validated_statistical           Mplus ESTIMATOR=BAYES
#> 20       validated_statistical           Mplus ESTIMATOR=BAYES
#> 21       validated_statistical           Mplus ESTIMATOR=BAYES
#> 22       validated_statistical           Mplus ESTIMATOR=BAYES
#> 23       validated_statistical           Mplus ESTIMATOR=BAYES
#> 24       validated_statistical           Mplus ESTIMATOR=BAYES
#> 25       validated_statistical           Mplus ESTIMATOR=BAYES
#> 26       validated_statistical           Mplus ESTIMATOR=BAYES
#> 32       validated_statistical           Mplus ESTIMATOR=BAYES
#> 33       validated_statistical           Mplus ESTIMATOR=BAYES
#> 27       validated_statistical           Mplus ESTIMATOR=BAYES
#> 28       validated_statistical           Mplus ESTIMATOR=BAYES
#> 29       validated_statistical           Mplus ESTIMATOR=BAYES
#> 30       validated_statistical           Mplus ESTIMATOR=BAYES
#> 31       validated_statistical           Mplus ESTIMATOR=BAYES
#> 34       validated_statistical           Mplus ESTIMATOR=BAYES
#> 12            validated_engine            idiographic::fit_var
#> 13            validated_engine            idiographic::fit_var
#> 14            validated_engine            idiographic::fit_var
#> 15            validated_engine            idiographic::fit_var
#> 16            validated_engine            idiographic::fit_var
#> 17            validated_engine            idiographic::fit_var
#> 18            validated_engine            idiographic::fit_var
#> 292         validated_internal  registered estimator summaries
#> 293         validated_internal  registered estimator summaries
#> 295         validated_internal  registered estimator summaries
#> 296         validated_internal  registered estimator summaries
#> 297         validated_internal  registered estimator summaries
#> 299         validated_internal  registered estimator summaries
#> 294         validated_internal  registered estimator summaries
#> 298         validated_internal  registered estimator summaries
#> 300         validated_internal  direct fitted-model prediction
#> 301         validated_internal  direct fitted-model prediction
#> 303         validated_internal  direct fitted-model prediction
#> 304         validated_internal  direct fitted-model prediction
#> 305         validated_internal  direct fitted-model prediction
#> 311         validated_internal  direct fitted-model prediction
#> 312         validated_internal  direct fitted-model prediction
#> 313         validated_internal  direct fitted-model prediction
#> 315         validated_internal  direct fitted-model prediction
#> 302         validated_internal  direct fitted-model prediction
#> 308         validated_internal  direct fitted-model prediction
#> 314         validated_internal  direct fitted-model prediction
#> 310         validated_internal  direct fitted-model prediction
#> 306         validated_internal  direct fitted-model prediction
#> 307         validated_internal  direct fitted-model prediction
#> 309         validated_internal  direct fitted-model prediction
#> 262         validated_internal       shared lag-design engines
#> 263         validated_internal       shared lag-design engines
#> 264         validated_internal       shared lag-design engines
#> 265         validated_internal       shared lag-design engines
#> 266         validated_internal       shared lag-design engines
#> 267         validated_internal       shared lag-design engines
#> 268         validated_internal       shared lag-design engines
#> 271         validated_internal       shared lag-design engines
#> 272         validated_internal       shared lag-design engines
#> 273         validated_internal       shared lag-design engines
#> 269         validated_internal       shared lag-design engines
#> 270         validated_internal       shared lag-design engines
#> 274         validated_internal       shared lag-design engines
#> 275         validated_internal       shared lag-design engines
#> 276         validated_internal       shared lag-design engines
#> 277         validated_internal       shared lag-design engines
#> 278         validated_internal       shared lag-design engines
#> 279         validated_internal      registered base estimators
#> 280         validated_internal      registered base estimators
#> 282         validated_internal      registered base estimators
#> 283         validated_internal      registered base estimators
#> 284         validated_internal      registered base estimators
#> 291         validated_internal      registered base estimators
#> 289         validated_internal      registered base estimators
#> 281         validated_internal      registered base estimators
#> 290         validated_internal      registered base estimators
#> 285         validated_internal      registered base estimators
#> 286         validated_internal      registered base estimators
#> 287         validated_internal      registered base estimators
#> 288         validated_internal      registered base estimators
#>                                                                                                                                                                                                                                                                                                                                                                                                           scope
#> 161                                                                                          `data`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 162                                                                                          `vars`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 163                                                                                            `id`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 165                                                                                           `day`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 166                                                                                          `beep`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 167                                                                                       `min_obs`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 168                                                                                       `subject`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 182                                                                                          `seed`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 170                                                                                   `standardize`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 164                                                                                          `time`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 180                                                                                    `cfi_cutoff`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 177                                                                                  `rmsea_cutoff`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 178                                                                                   `srmr_cutoff`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 173                                                                                         `paths`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 174                                                                                     `exogenous`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 169 `ar`: The supported AR path is oracle-tested; upstream gimme 10.0 fails on the audited ar=FALSE fixture, which remains a local extension. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 171                                                                                   `groupcutoff`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 172                 `subcutoff`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 175                                                                                        `hybrid`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 176                                                                                           `VAR`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 179                                                                                   `nnfi_cutoff`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 181                                                                                   `n_excellent`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 183                                                                                 `group_correct`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 184                                                                                 `indiv_correct`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 185                                                                                         `alpha`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 186                                                                                     `stop_crit`: Evidence class: validated_oracle_matrix. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 187                                                                   `subgroup`: Non-default use errors explicitly; no silent support claim. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 188                                                                    `outcome`: Non-default use errors explicitly; no silent support claim. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 189                                                                  `conv_vars`: Non-default use errors explicitly; no silent support claim. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 190                                                                  `mult_vars`: Non-default use errors explicitly; no silent support claim. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 191                                                                   `lv_model`: Non-default use errors explicitly; no silent support claim. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 192                                                           `lasso_model_crit`: Non-default use errors explicitly; no silent support claim. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 193                                                                   `ms_allow`: Non-default use errors explicitly; no silent support claim. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 194                                                                    `ordered`: Non-default use errors explicitly; no silent support claim. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 195                                                            `dir_prop_cutoff`: Non-default use errors explicitly; no silent support claim. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 196                       `out`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 197                       `sep`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 198                    `header`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 199                      `plot`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 200               `sub_feature`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 201                `sub_method`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 202            `sub_sim_thresh`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 203          `confirm_subgroup`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 204               `conv_length`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 205             `conv_interval`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 206          `mean_center_mult`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 207                   `diagnos`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 208                    `ms_tol`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 209              `lv_estimator`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 210                 `lv_scores`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 211           `lv_miiv_scaling`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 212        `lv_final_estimator`: Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope. Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 35                                                                                                                                                                                                                                                                                                     `data`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 36                                                                                                                                                                                                                                                                                                     `vars`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 37                                                                                                                                                                                                                                                                                                       `id`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 38                                                                                                                                                                                                                                                                                                      `day`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 39                                                                                                                                                                                                                                                                                                     `beep`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 40                                                                                                                                                                                                                           `lags`: Competitor-compatible values are oracle-tested; additional tidy values are labelled idiographic extensions. Supported lag-1 settings, including tested beta/kappa options.
#> 43                                                                                                                                                                                                                                                                                                    `scale`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 44                                                                                                                                                                                                                                                                                            `center_within`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 55                                                                                                                                                                                                                                                                                          `delete_missings`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 60                                                                                                                                                                                                                                                                                                `min_obs`: Evidence class: validated_behavior. Supported lag-1 settings, including tested beta/kappa options.
#> 61                                                                                                                                                                                                                                                                                                `subject`: Evidence class: validated_behavior. Supported lag-1 settings, including tested beta/kappa options.
#> 59                                                                                                                                                                                                                                                                                                `verbose`: Evidence class: validated_behavior. Supported lag-1 settings, including tested beta/kappa options.
#> 41                                                                                                                                                                                                                       `n_lambda`: Competitor-compatible values are oracle-tested; additional tidy values are labelled idiographic extensions. Supported lag-1 settings, including tested beta/kappa options.
#> 42                                                                                                                                                                                                                                                                                                    `gamma`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 45                                                                                                                                                                                                                                                                                         `lambda_min_ratio`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 46                                                                                                                                                                                                                                                                                         `lambda_min_kappa`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 47                                                                                                                                                                                                                                                                                          `lambda_min_beta`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 48                                                                                                                                                                                                                                                                                        `penalize_diagonal`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 49                                                                                                                                                                                                                                                                                              `lambda_beta`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 50                                                                                                                                                                                                                                                                                             `lambda_kappa`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 51                                                                                                                                                                                                                                                                                      `regularize_mat_beta`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 52                                                                                                                                                                                                                                                                                     `regularize_mat_kappa`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 53                                                                                                                                                                                                                                                                                                 `maxit_in`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 54                                                                                                                                                                                                                                                                                                `maxit_out`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 56                                                                                                                                                                                                                                                                                               `likelihood`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 57                                                                                                                                                                                                                                                                                                 `ebic_tol`: Evidence class: validated_oracle. Supported lag-1 settings, including tested beta/kappa options.
#> 58                                                                                                                                                                                                                                                               `mimic`: Supported values are tested; unused or legacy values error explicitly. Supported lag-1 settings, including tested beta/kappa options.
#> 62                                                                                                                                                                                                                                                `data`: Evidence class: validated_wrapper. Every returned subject fit is compared directly with an upstream lag-1 graphicalVAR fit on the same subject panel.
#> 63                                                                                                                                                                                                                                                `vars`: Evidence class: validated_wrapper. Every returned subject fit is compared directly with an upstream lag-1 graphicalVAR fit on the same subject panel.
#> 64                                                                                                                                                                                                                                                  `id`: Evidence class: validated_wrapper. Every returned subject fit is compared directly with an upstream lag-1 graphicalVAR fit on the same subject panel.
#> 65                                                                                                                                                                                                                                                 `day`: Evidence class: validated_wrapper. Every returned subject fit is compared directly with an upstream lag-1 graphicalVAR fit on the same subject panel.
#> 66                                                                                                                                                                                                                                                `beep`: Evidence class: validated_wrapper. Every returned subject fit is compared directly with an upstream lag-1 graphicalVAR fit on the same subject panel.
#> 67                                                                                                                                                                                                                                             `min_obs`: Evidence class: validated_wrapper. Every returned subject fit is compared directly with an upstream lag-1 graphicalVAR fit on the same subject panel.
#> 68                                                                                                                                                                                                                                              `...`: Evidence class: validated_forwarding. Every returned subject fit is compared directly with an upstream lag-1 graphicalVAR fit on the same subject panel.
#> 240                                                                                                                                                                                             `data`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 243                                                                                                                                                                                               `id`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 244                                                                                                                                                                                              `day`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 245                                                                                                                                                                                             `beep`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 261                                                                                                                                                                                              `...`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 248                                                                                                                                                                                        `estimator`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 259                                                                                                                                                                                      `standardize`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 254                                                                                                                                                                                            `alpha`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 241                                                                                                                                                                                          `outcome`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 260                                                                                                                                                                                        `keep_fits`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 242                                                                                                                                                                                       `predictors`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 246                                                                                                                                                                                             `task`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 247                                                                                                                                                                                            `model`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 249                                                                                                                                                                                          `compare`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 250                                                                                                                                                                                        `test_prop`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 251                                                                                                                                                                                        `min_train`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 252                                                                                                                                                                                         `min_test`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 253                                                                                                                                                                                           `lambda`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 255                                                                                                                                                                                                `k`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 256                                                                                                                                                                                     `n_components`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 257                                                                                                                                                                                         `max_iter`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 258                                                                                                                                                                                              `tol`: Evidence class: validated_native. All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 69                                                                                                                                                                                                                                   `data`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 70                                                                                                                                                                                                                                   `vars`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 71                                                                                                                                                                                                                                     `id`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 72                                                                                                                                                                                                                                    `day`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 73                                                                                                                                                                                                                                   `beep`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 74                                                                                                                                                                      `lags`: The fitted object's equivalence declaration is refined from the selected engine and structure. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 79                                                                                                                                                                                                                                  `scale`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 85                                                                                                                                                                                                                              `min_obs`: Evidence class: validated_behavior. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 86                                                                                                                                                                                                                              `subject`: Evidence class: validated_behavior. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 95                                                                                                                                                                                               `...`: Supported values are tested; unused or legacy values error explicitly. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 82                                                                                                                                                                                                                              `verbose`: Evidence class: validated_behavior. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 75                                                                                                                                                                 `estimator`: The fitted object's equivalence declaration is refined from the selected engine and structure. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 76                                                                                                                                                                  `temporal`: The fitted object's equivalence declaration is refined from the selected engine and structure. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 77                                                                                                                                                           `contemporaneous`: The fitted object's equivalence declaration is refined from the selected engine and structure. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 78                                                                                                                                                                                                                                     `AR`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 80                                                                                                                                                                                                                            `scaleWithin`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 81                                                                                                                                                                                                                                 `nCores`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 83                                                                                                                                                                                                                                    `lag`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 84                                                                                                                                                                                                                            `standardize`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 87                                                                                                                                                                    `engine`: The fitted object's equivalence declaration is refined from the selected engine and structure. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 88                                                                                                                                                                                                                       `standardize_mode`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 89                                                                                                                                                                                                                              `missing`: Evidence class: validated_behavior. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 90                                                                                                                                                                                                                        `compare_to_lags`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 91                                                                                                                                                                                                                             `true_means`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 92                                                                                                                                                                                                                                `detrend`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 93                                                                                                                                                                                                                                  `na_rm`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 94                                                                                                                                                                                                                             `orthogonal`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 96                                                                                                                                                                                                           `data`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 97                                                                                                                                                                                                           `vars`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 98                                                                                                                                                                                                             `id`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 99                                                                                                                                                                                                            `day`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 100                                                                                                                                                                                                          `beep`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 101                                                                                                                                                                                                          `lags`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 105                                                                                                                                                                                                         `scale`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 114                                                                                                                                                                                                       `min_obs`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 115                                                                                                                                                                                                       `subject`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 109                                                                                                                                                                                                        `n_iter`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 110                                                                                                                                                                                                      `n_burnin`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 111                                                                                                                                                                                                      `n_chains`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 112                                                                                                                                                                                                          `thin`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 113                                                                                                                                                                                                          `seed`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 116                                                                                                                                                                                                       `verbose`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 102                                                                                                                     `temporal`: Fixed/checkable slices use external fixtures; advanced native slices use planted recovery and are labelled accordingly. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 103                                                                                                                                                                                               `contemporaneous`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 106                                                                                                                                                                                                   `scaleWithin`: Evidence class: validated_statistical. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 104                                                                                                                     `residual`: Fixed/checkable slices use external fixtures; advanced native slices use planted recovery and are labelled accordingly. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 107                                                                                                                    `tinterval`: Fixed/checkable slices use external fixtures; advanced native slices use planted recovery and are labelled accordingly. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 108                                                                                                                       `impute`: Fixed/checkable slices use external fixtures; advanced native slices use planted recovery and are labelled accordingly. Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 117                                                                                                                                                        `data`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 118                                                                                                                                                        `vars`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 119                                                                                                                                                          `id`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 120                                                                                                                                                         `day`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 121                                                                                                                                                        `beep`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 122                                                                                                                                                        `lags`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 126                                                                                                                                                       `scale`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 133                                                                                                                                                                                                                            `min_obs`: Evidence class: validated_behavior. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 134                                                                                                                                                                                                                            `subject`: Evidence class: validated_behavior. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 137                                                                                                                                                         `...`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 136                                                                                                                                                     `verbose`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 123                                                                                                                                                    `temporal`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 124                                                                                                                                             `contemporaneous`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 127                                                                                                                                                 `scaleWithin`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 125                                                                                                                                                      `nCores`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 128                                                                                                                                                   `MplusSave`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 129                                                                                                                                                   `MplusName`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 130                                                                                                                                                  `iterations`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 131                                                                                                                                                      `chains`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 132                                                                                                                                                       `signs`: Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 135                                                                                                                                                                                                                            `workdir`: Evidence class: validated_behavior. Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 226                                                                                                                                                                                                                            `data`: Evidence class: validated_internal. Every retained window is a registered graphical VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 227                                                                                                                                                                                                                            `vars`: Evidence class: validated_internal. Every retained window is a registered graphical VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 228                                                                                                                                                                                                                              `id`: Evidence class: validated_internal. Every retained window is a registered graphical VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 229                                                                                                                                                                                                                             `day`: Evidence class: validated_internal. Every retained window is a registered graphical VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 230                                                                                                                                                                                                                            `beep`: Evidence class: validated_internal. Every retained window is a registered graphical VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 233                                                                                                                                                                                                                           `scale`: Evidence class: validated_internal. Every retained window is a registered graphical VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 234                                                                                                                                                                                                                   `center_within`: Evidence class: validated_internal. Every retained window is a registered graphical VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 235                                                                                                                                                                                                                 `delete_missings`: Evidence class: validated_internal. Every retained window is a registered graphical VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 236                                                                                                                                                                                                                         `min_obs`: Evidence class: validated_internal. Every retained window is a registered graphical VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 237                                                                                                                                                                                                                         `subject`: Evidence class: validated_internal. Every retained window is a registered graphical VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 239                                                                                                                                                                                                                             `...`: Evidence class: validated_internal. Every retained window is a registered graphical VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 231                                                                                                                                                                                                                     `window_size`: Evidence class: validated_internal. Every retained window is a registered graphical VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 232                                                                                                                                                                                                                            `step`: Evidence class: validated_internal. Every retained window is a registered graphical VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 238                                                                                                                                                                                                                       `keep_fits`: Evidence class: validated_internal. Every retained window is a registered graphical VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 213                                                                                                                                                                                                                                      `data`: Evidence class: validated_internal. Every retained window is a registered VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 214                                                                                                                                                                                                                                      `vars`: Evidence class: validated_internal. Every retained window is a registered VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 215                                                                                                                                                                                                                                        `id`: Evidence class: validated_internal. Every retained window is a registered VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 216                                                                                                                                                                                                                                       `day`: Evidence class: validated_internal. Every retained window is a registered VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 217                                                                                                                                                                                                                                      `beep`: Evidence class: validated_internal. Every retained window is a registered VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 220                                                                                                                                                                                                                                     `scale`: Evidence class: validated_internal. Every retained window is a registered VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 221                                                                                                                                                                                                                             `center_within`: Evidence class: validated_internal. Every retained window is a registered VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 222                                                                                                                                                                                                                           `delete_missings`: Evidence class: validated_internal. Every retained window is a registered VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 223                                                                                                                                                                                                                                   `min_obs`: Evidence class: validated_internal. Every retained window is a registered VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 224                                                                                                                                                                                                                                   `subject`: Evidence class: validated_internal. Every retained window is a registered VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 218                                                                                                                                                                                                                               `window_size`: Evidence class: validated_internal. Every retained window is a registered VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 219                                                                                                                                                                                                                                      `step`: Evidence class: validated_internal. Every retained window is a registered VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 225                                                                                                                                                                                                                                 `keep_fits`: Evidence class: validated_internal. Every retained window is a registered VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 138                                                                                                                                                                                                                                                `data`: Evidence class: validated_engine. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 139                                                                                                                                                                                                                                                `vars`: Evidence class: validated_engine. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 140                                                                                                                                                                                                                                                  `id`: Evidence class: validated_engine. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 142                                                                                                                                                                                                                                                 `day`: Evidence class: validated_engine. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 143                                                                                                                                                                                                                                                `beep`: Evidence class: validated_engine. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 144                                                                                                                                                                                                                                             `min_obs`: Evidence class: validated_engine. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 145                                                                                                                                                                                                                                             `subject`: Evidence class: validated_engine. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 160                                                                                                                                                                                                                                                `seed`: Evidence class: validated_engine. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 159                                                                                                                                                                                                                                           `estimator`: Evidence class: validated_engine. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 146                                                                                                                                                                                                                                            `temporal`: Evidence class: validated_engine. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 147                                                                                                                                                                                                                                     `contemporaneous`: Evidence class: validated_engine. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 158                                                                                                                                                                                                                                         `standardize`: Evidence class: validated_engine. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 141                                                                                                                                                                                                                                                `time`: Evidence class: validated_engine. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 148                                                                                                                                                                                                                                        `residual_cov`: Evidence class: validated_engine. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 149                                                                                                                                                                                                                                             `trim`: Evidence class: validated_extension. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 150                                                                                                                                                                                                                                       `trim_alpha`: Evidence class: validated_extension. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 151                                                                                                                                                                                                                                `trim_fit_criteria`: Evidence class: validated_extension. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 152                                                                                                                                                                                                                                       `cfi_cutoff`: Evidence class: validated_extension. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 153                                                                                                                                                                                                                                       `tli_cutoff`: Evidence class: validated_extension. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 154                                                                                                                                                                                                                                     `rmsea_cutoff`: Evidence class: validated_extension. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 155                                                                                                                                                                                                                                      `srmr_cutoff`: Evidence class: validated_extension. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 156                                                                                                                                                                                                                                               `paths`: Evidence class: validated_engine. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 157                                                                                                                                                                                                                                           `exogenous`: Evidence class: validated_engine. Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 1                                                                                                                                                                                                                                                                                                    `data`: Evidence class: validated_engine. OLS coefficient engine and package-defined VAR(1) preprocessing.
#> 2                                                                                                                                                                                                                                                                                                    `vars`: Evidence class: validated_engine. OLS coefficient engine and package-defined VAR(1) preprocessing.
#> 3                                                                                                                                                                                                                                                                                                      `id`: Evidence class: validated_engine. OLS coefficient engine and package-defined VAR(1) preprocessing.
#> 4                                                                                                                                                                                                                                                                                                     `day`: Evidence class: validated_engine. OLS coefficient engine and package-defined VAR(1) preprocessing.
#> 5                                                                                                                                                                                                                                                                                                    `beep`: Evidence class: validated_engine. OLS coefficient engine and package-defined VAR(1) preprocessing.
#> 6                                                                                                                                                                                                                                                                                                    `lags`: Evidence class: validated_engine. OLS coefficient engine and package-defined VAR(1) preprocessing.
#> 7                                                                                                                                                                                                                                                                                                   `scale`: Evidence class: validated_engine. OLS coefficient engine and package-defined VAR(1) preprocessing.
#> 8                                                                                                                                                                                                                                                                                           `center_within`: Evidence class: validated_engine. OLS coefficient engine and package-defined VAR(1) preprocessing.
#> 9                                                                                                                                                                                                                                                                                         `delete_missings`: Evidence class: validated_engine. OLS coefficient engine and package-defined VAR(1) preprocessing.
#> 10                                                                                                                                                                                                                                                                                                `min_obs`: Evidence class: validated_engine. OLS coefficient engine and package-defined VAR(1) preprocessing.
#> 11                                                                                                                                                                                                                                                                                                `subject`: Evidence class: validated_engine. OLS coefficient engine and package-defined VAR(1) preprocessing.
#> 19                                                                                                                                                                                                                                           `data`: Evidence class: validated_statistical. Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 20                                                                                                                                                                                                                                           `vars`: Evidence class: validated_statistical. Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 21                                                                                                                                                                                                                                             `id`: Evidence class: validated_statistical. Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 22                                                                                                                                                                                                                                            `day`: Evidence class: validated_statistical. Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 23                                                                                                                                                                                                                                           `beep`: Evidence class: validated_statistical. Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 24                                                                                                                                                                                                                                           `lags`: Evidence class: validated_statistical. Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 25                                                                                                                                                                                                                                          `scale`: Evidence class: validated_statistical. Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 26                                                                                                                                                                                                                                  `center_within`: Evidence class: validated_statistical. Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 32                                                                                                                                                                                                                                        `min_obs`: Evidence class: validated_statistical. Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 33                                                                                                                                                                                                                                        `subject`: Evidence class: validated_statistical. Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 27                                                                                                                                                                                                                                         `n_iter`: Evidence class: validated_statistical. Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 28                                                                                                                                                                                                                                       `n_burnin`: Evidence class: validated_statistical. Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 29                                                                                                                                                                                                                                       `n_chains`: Evidence class: validated_statistical. Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 30                                                                                                                                                                                                                                           `thin`: Evidence class: validated_statistical. Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 31                                                                                                                                                                                                                                           `seed`: Evidence class: validated_statistical. Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 34                                                                                                                                                                                                                                        `verbose`: Evidence class: validated_statistical. Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 12                                                                                                                                                                                                                                                                                                                                `data`: Evidence class: validated_engine. Exact per-subject wrapper behavior.
#> 13                                                                                                                                                                                                                                                                                                                                `vars`: Evidence class: validated_engine. Exact per-subject wrapper behavior.
#> 14                                                                                                                                                                                                                                                                                                                                  `id`: Evidence class: validated_engine. Exact per-subject wrapper behavior.
#> 15                                                                                                                                                                                                                                                                                                                                 `day`: Evidence class: validated_engine. Exact per-subject wrapper behavior.
#> 16                                                                                                                                                                                                                                                                                                                                `beep`: Evidence class: validated_engine. Exact per-subject wrapper behavior.
#> 17                                                                                                                                                                                                                                                                                                                             `min_obs`: Evidence class: validated_engine. Exact per-subject wrapper behavior.
#> 18                                                                                                                                                                                                                                                                                                                                 `...`: Evidence class: validated_engine. Exact per-subject wrapper behavior.
#> 292                                                                                                                                                                                                                                                                                              `data`: Evidence class: validated_internal. Exact stacking, dispatch, argument routing, and failure isolation.
#> 293                                                                                                                                                                                                                                                                                              `vars`: Evidence class: validated_internal. Exact stacking, dispatch, argument routing, and failure isolation.
#> 295                                                                                                                                                                                                                                                                                                `id`: Evidence class: validated_internal. Exact stacking, dispatch, argument routing, and failure isolation.
#> 296                                                                                                                                                                                                                                                                                               `day`: Evidence class: validated_internal. Exact stacking, dispatch, argument routing, and failure isolation.
#> 297                                                                                                                                                                                                                                                                                              `beep`: Evidence class: validated_internal. Exact stacking, dispatch, argument routing, and failure isolation.
#> 299                                                                                                                                                                                                                                                                                         `keep_fits`: Evidence class: validated_internal. Exact stacking, dispatch, argument routing, and failure isolation.
#> 294                                                                                                                                                                                                                                                                                        `estimators`: Evidence class: validated_internal. Exact stacking, dispatch, argument routing, and failure isolation.
#> 298                                                                                                                                                                                                                                                                                    `estimator_args`: Evidence class: validated_internal. Exact stacking, dispatch, argument routing, and failure isolation.
#> 300                                                                                                                                                                                                                               `data`: Evidence class: validated_internal. Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 301                                                                                                                                                                                                                               `vars`: Evidence class: validated_internal. Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 303                                                                                                                                                                                                                                 `id`: Evidence class: validated_internal. Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 304                                                                                                                                                                                                                                `day`: Evidence class: validated_internal. Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 305                                                                                                                                                                                                                               `beep`: Evidence class: validated_internal. Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 311                                                                                                                                                                                                                              `scale`: Evidence class: validated_internal. Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 312                                                                                                                                                                                                                      `center_within`: Evidence class: validated_internal. Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 313                                                                                                                                                                                                                    `delete_missings`: Evidence class: validated_internal. Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 315                                                                                                                                                                                                                                `...`: Evidence class: validated_internal. Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 302                                                                                                                                                                                                                          `estimator`: Evidence class: validated_internal. Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 308                                                                                                                                                                                                                               `step`: Evidence class: validated_internal. Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 314                                                                                                                                                                                                                          `keep_fits`: Evidence class: validated_internal. Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 310                                                                                                                                                                                                                         `block_size`: Evidence class: validated_internal. Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 306                                                                                                                                                                                                                            `initial`: Evidence class: validated_internal. Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 307                                                                                                                                                                                                                             `assess`: Evidence class: validated_internal. Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 309                                                                                                                                                                                                                           `n_splits`: Evidence class: validated_internal. Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 262                                                                                                                                                                                                                               `data`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 263                                                                                                                                                                                                                               `vars`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 264                                                                                                                                                                                                                                 `id`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 265                                                                                                                                                                                                                                `day`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 266                                                                                                                                                                                                                               `beep`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 267                                                                                                                                                                                                                              `scale`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 268                                                                                                                                                                                                                      `center_within`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 271                                                                                                                                                                                                                    `delete_missings`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 272                                                                                                                                                                                                                            `min_obs`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 273                                                                                                                                                                                                                            `subject`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 269                                                                                                                                                                                                                            `detrend`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 270                                                                                                                                                                                                                             `checks`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 274                                                                                                                                                                                                                        `trend_alpha`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 275                                                                                                                                                                                                                       `ar_threshold`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 276                                                                                                                                                                                                               `mean_shift_threshold`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 277                                                                                                                                                                                                                 `sd_ratio_threshold`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 278                                                                                                                                                                                                                 `unit_root_t_cutoff`: Evidence class: validated_internal. Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 279                                                                                                                                                                                                                            `data`: Evidence class: validated_internal. Deterministic block/split-half resampling, ordering invariants, and five-estimator dispatch contracts; no unrelated external target.
#> 280                                                                                                                                                                                                                            `vars`: Evidence class: validated_internal. Deterministic block/split-half resampling, ordering invariants, and five-estimator dispatch contracts; no unrelated external target.
#> 282                                                                                                                                                                                                                              `id`: Evidence class: validated_internal. Deterministic block/split-half resampling, ordering invariants, and five-estimator dispatch contracts; no unrelated external target.
#> 283                                                                                                                                                                                                                             `day`: Evidence class: validated_internal. Deterministic block/split-half resampling, ordering invariants, and five-estimator dispatch contracts; no unrelated external target.
#> 284                                                                                                                                                                                                                            `beep`: Evidence class: validated_internal. Deterministic block/split-half resampling, ordering invariants, and five-estimator dispatch contracts; no unrelated external target.
#> 291                                                                                                                                                                                                                             `...`: Evidence class: validated_internal. Deterministic block/split-half resampling, ordering invariants, and five-estimator dispatch contracts; no unrelated external target.
#> 289                                                                                                                                                                                                                            `seed`: Evidence class: validated_internal. Deterministic block/split-half resampling, ordering invariants, and five-estimator dispatch contracts; no unrelated external target.
#> 281                                                                                                                                                                                                                       `estimator`: Evidence class: validated_internal. Deterministic block/split-half resampling, ordering invariants, and five-estimator dispatch contracts; no unrelated external target.
#> 290                                                                                                                                                                                                                       `keep_fits`: Evidence class: validated_internal. Deterministic block/split-half resampling, ordering invariants, and five-estimator dispatch contracts; no unrelated external target.
#> 285                                                                                                                                                                                                                     `n_resamples`: Evidence class: validated_internal. Deterministic block/split-half resampling, ordering invariants, and five-estimator dispatch contracts; no unrelated external target.
#> 286                                                                                                                                                                                                                        `resample`: Evidence class: validated_internal. Deterministic block/split-half resampling, ordering invariants, and five-estimator dispatch contracts; no unrelated external target.
#> 287                                                                                                                                                                                                                      `block_size`: Evidence class: validated_internal. Deterministic block/split-half resampling, ordering invariants, and five-estimator dispatch contracts; no unrelated external target.
#> 288                                                                                                                                                                                                                       `threshold`: Evidence class: validated_internal. Deterministic block/split-half resampling, ordering invariants, and five-estimator dispatch contracts; no unrelated external target.
argument_coverage("mlvar")
#>    method      kind         argument                status    reference
#> 1   mlvar estimator             data      validated_oracle mlVAR::mlVAR
#> 2   mlvar estimator             vars      validated_oracle mlVAR::mlVAR
#> 3   mlvar estimator               id      validated_oracle mlVAR::mlVAR
#> 4   mlvar estimator              day      validated_oracle mlVAR::mlVAR
#> 5   mlvar estimator             beep      validated_oracle mlVAR::mlVAR
#> 6   mlvar estimator             lags        mode_dependent mlVAR::mlVAR
#> 7   mlvar estimator        estimator        mode_dependent mlVAR::mlVAR
#> 8   mlvar estimator         temporal        mode_dependent mlVAR::mlVAR
#> 9   mlvar estimator  contemporaneous        mode_dependent mlVAR::mlVAR
#> 10  mlvar estimator               AR      validated_oracle mlVAR::mlVAR
#> 11  mlvar estimator            scale      validated_oracle mlVAR::mlVAR
#> 12  mlvar estimator      scaleWithin      validated_oracle mlVAR::mlVAR
#> 13  mlvar estimator           nCores      validated_oracle mlVAR::mlVAR
#> 14  mlvar estimator          verbose    validated_behavior mlVAR::mlVAR
#> 15  mlvar estimator              lag      validated_oracle mlVAR::mlVAR
#> 16  mlvar estimator      standardize      validated_oracle mlVAR::mlVAR
#> 17  mlvar estimator          min_obs    validated_behavior mlVAR::mlVAR
#> 18  mlvar estimator          subject    validated_behavior mlVAR::mlVAR
#> 19  mlvar estimator           engine        mode_dependent mlVAR::mlVAR
#> 20  mlvar estimator standardize_mode      validated_oracle mlVAR::mlVAR
#> 21  mlvar estimator          missing    validated_behavior mlVAR::mlVAR
#> 22  mlvar estimator  compare_to_lags      validated_oracle mlVAR::mlVAR
#> 23  mlvar estimator       true_means      validated_oracle mlVAR::mlVAR
#> 24  mlvar estimator          detrend      validated_oracle mlVAR::mlVAR
#> 25  mlvar estimator            na_rm      validated_oracle mlVAR::mlVAR
#> 26  mlvar estimator       orthogonal      validated_oracle mlVAR::mlVAR
#> 27  mlvar estimator              ... validated_or_rejected mlVAR::mlVAR
#>                                                                                                                                                                                                                                                 scope
#> 1                                                                          `data`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 2                                                                          `vars`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 3                                                                            `id`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 4                                                                           `day`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 5                                                                          `beep`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 6             `lags`: The fitted object's equivalence declaration is refined from the selected engine and structure. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 7        `estimator`: The fitted object's equivalence declaration is refined from the selected engine and structure. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 8         `temporal`: The fitted object's equivalence declaration is refined from the selected engine and structure. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 9  `contemporaneous`: The fitted object's equivalence declaration is refined from the selected engine and structure. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 10                                                                           `AR`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 11                                                                        `scale`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 12                                                                  `scaleWithin`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 13                                                                       `nCores`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 14                                                                    `verbose`: Evidence class: validated_behavior. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 15                                                                          `lag`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 16                                                                  `standardize`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 17                                                                    `min_obs`: Evidence class: validated_behavior. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 18                                                                    `subject`: Evidence class: validated_behavior. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 19          `engine`: The fitted object's equivalence declaration is refined from the selected engine and structure. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 20                                                             `standardize_mode`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 21                                                                    `missing`: Evidence class: validated_behavior. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 22                                                              `compare_to_lags`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 23                                                                   `true_means`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 24                                                                      `detrend`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 25                                                                        `na_rm`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 26                                                                   `orthogonal`: Evidence class: validated_oracle. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 27                                     `...`: Supported values are tested; unused or legacy values error explicitly. Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
```
