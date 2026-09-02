# Discover subgroups of people

Groups people who behave alike, so that a model can be fitted per
subgroup rather than pooling everyone or fitting everyone separately.

## Usage

``` r
find_subgroups(
  data,
  y,
  x,
  id,
  method = c("effect_clustering", "error_clustering", "repeated_split", "model_tree",
    "mixture_regression", "random_partition"),
  k = 2L,
  reps = 50L,
  moderators = NULL,
  time = NULL,
  k_max = 6L,
  ...
)
```

## Arguments

- data:

  Data frame.

- y:

  Outcome column name.

- x:

  Predictors (any
  [`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md)
  selector).

- id:

  Person/unit ID column.

- method:

  Discovery method.

- k:

  Number of subgroups, or `"auto"` to choose it by stability.

- reps:

  Resamples used for the stability score.

- moderators:

  Person-level column(s) to split on. Required by
  `method = "model_tree"`, ignored otherwise. Must be constant within
  person.

- time:

  Optional ordering column.

- k_max:

  Largest `k` considered when `k = "auto"`.

- ...:

  Ignored.

## Value

An `idiographic_groups` object. Use
[`groups()`](https://pak.dynasite.org/idiographic/reference/groups.md)
for the tidy table.

## Details

Methods:

- `effect_clustering`:

  Cluster people by their person-specific slopes. People whose
  predictors act the same way land together.

- `error_clustering`:

  Cluster people by how a pooled model fails them (error size and
  direction). Finds who the pooled model does not serve.

- `repeated_split`:

  Like `effect_clustering`, but slopes are recomputed on repeated
  resamples, so unstable people are exposed.

- `model_tree`:

  Split people on person-level `moderators` (age, condition, baseline
  score) to reduce prediction error. The only method that says *why*
  people differ, in terms of variables you measured.

- `mixture_regression`:

  A finite mixture of regressions fitted by EM, with the **person** as
  the mixing unit: every row a person contributes counts towards that
  person's likelihood under each component, so people are assigned
  whole. Unlike `effect_clustering` it does not need a separate
  regression per person, so it can place people with too few occasions
  to support one. `$mixture` holds the component regressions and the
  posterior probabilities, and
  [`groups()`](https://pak.dynasite.org/idiographic/reference/groups.md)
  gains a `posterior` column – how sure the model is of each assignment,
  which is a stronger statement than how often a partition reproduces.
  Matches `flexmix::flexmix(y ~ x | id)` to the reported precision on
  log-likelihood, BIC and assignment.

- `random_partition`:

  Random labels. A null baseline: compare its stability against a real
  method to see whether structure exists.

**These methods always return subgroups, including when there are
none.** Call
[`test_subgroups()`](https://pak.dynasite.org/idiographic/reference/test_subgroups.md)
first, or use `k = "auto"`, which is allowed to answer "one population".

Stability is a consensus score: each person is repeatedly re-clustered
on resampled rows, and stability is how often they land with the same
companions. It measures whether a partition is **reproducible, not
whether it is real**. In simulation, data containing no subgroups at all
scored 0.89-0.97 – because slicing a single smooth cloud of coefficients
in half is highly repeatable. Do not read a high stability as evidence
that the groups exist.

With `k = "auto"` the number of subgroups is chosen by
[`test_subgroups()`](https://pak.dynasite.org/idiographic/reference/test_subgroups.md),
a Gaussian mixture on the person coefficients selected by BIC over both
the number of components and the covariance structure. It may return
**one**, in which case a warning is raised and the partition should not
be trusted. See `$selection` for the BIC table and `$shape` for the
skewness diagnostic.

`method = "mixture_regression"` defers to the same test rather than to
its own BIC, and the reason is worth knowing. On 30 simulated panels
containing **no** subgroups – one population whose slopes merely varied
continuously – the mixture's BIC chose more than one component **30
times out of 30**, while
[`test_subgroups()`](https://pak.dynasite.org/idiographic/reference/test_subgroups.md)
answered "one population" 30 times out of 30 and still recovered two
real classes when they were present. A mixture of regressions fits a
continuum of slopes better with two components than with one, and its
BIC has no device to tell that apart from genuine classes. The mixture's
own BIC table is still reported in `$mixture_bic`, for comparison with a
`flexmix`-style workflow – it simply does not get to choose.

## Examples

``` r
g <- find_subgroups(srl, y = "effort", x = "efficacy:monitoring",
                    id = "name", k = 2, reps = 10)
groups(g)
#>    subject subgroup            method stability n_assignments
#> 1    Aisha       g2 effect_clustering 0.8411765            10
#> 2    Alice       g2 effect_clustering 0.9117647            10
#> 3    Anika       g1 effect_clustering 0.5823529            10
#> 4   Astrid       g1 effect_clustering 0.7941176            10
#> 5    Bjorn       g1 effect_clustering 0.4882353            10
#> 6      Bob       g2 effect_clustering 0.9117647            10
#> 7  Charlie       g1 effect_clustering 0.8647059            10
#> 8    Diana       g1 effect_clustering 0.8647059            10
#> 9     Erik       g1 effect_clustering 0.8647059            10
#> 10     Eve       g2 effect_clustering 0.9117647            10
#> 11  Fatima       g1 effect_clustering 0.8647059            10
#> 12   Frank       g1 effect_clustering 0.8647059            10
#> 13   Freja       g1 effect_clustering 0.8647059            10
#> 14   Grace       g1 effect_clustering 0.8647059            10
#> 15  Hassan       g2 effect_clustering 0.8411765            10
#> 16   Heidi       g1 effect_clustering 0.8058824            10
#> 17 Hiroshi       g2 effect_clustering 0.4764706            10
#> 18  Ingrid       g1 effect_clustering 0.4764706            10
#> 19    Ivan       g2 effect_clustering 0.9117647            10
#> 20    Judy       g2 effect_clustering 0.8294118            10
#> 21   Karin       g1 effect_clustering 0.3470588            10
#> 22    Lars       g2 effect_clustering 0.9117647            10
#> 23   Layla       g2 effect_clustering 0.9117647            10
#> 24      Li       g2 effect_clustering 0.9117647            10
#> 25     Liv       g2 effect_clustering 0.9117647            10
#> 26     Mei       g2 effect_clustering 0.7705882            10
#> 27    Nils       g1 effect_clustering 0.8647059            10
#> 28    Noor       g2 effect_clustering 0.5117647            10
#> 29    Omar       g2 effect_clustering 0.9117647            10
#> 30    Ravi       g1 effect_clustering 0.8647059            10
#> 31  Saanvi       g1 effect_clustering 0.8647059            10
#> 32  Sakura       g2 effect_clustering 0.9117647            10
#> 33    Sven       g2 effect_clustering 0.9117647            10
#> 34  Takumi       g1 effect_clustering 0.8647059            10
#> 35    Yuki       g1 effect_clustering 0.8647059            10
#> 36    Zain       g2 effect_clustering 0.9117647            10

# Let the data choose how many subgroups there are.
auto <- find_subgroups(srl, y = "effort", x = "efficacy:monitoring",
                       id = "name", k = "auto", k_max = 4, reps = 10)
#> Warning: No subgroups detected: one population fits these people best. Any partition returned below is not supported by the data.
auto$selection
#>    k model    loglik npar      bic selected
#> 1  1   EII -202.2988    5 422.5153     TRUE
#> 2  1   VII -202.2988    5 422.5153    FALSE
#> 3  2   EII -195.1972   10 426.2296    FALSE
#> 4  2   VII -194.5701   11 428.5589    FALSE
#> 5  2   EEI -191.4409   13 429.4675    FALSE
#> 6  1   EEE -191.2969   14 432.7631    FALSE
#> 7  1   VVV -191.2969   14 432.7631    FALSE
#> 8  1   EEI -202.2988    8 433.2658    FALSE
#> 9  1   VVI -202.2988    8 433.2658    FALSE
#> 10 3   VII -186.3938   17 433.7074    FALSE
#> 11 2   VVV -165.3181   29 434.5582    FALSE
#> 12 3   EII -191.2184   15 436.1897    FALSE
#> 13 2   EEE -185.1661   19 438.4190    FALSE
#> 14 2   VVI -189.2301   17 439.3800    FALSE
#> 15 3   EEI -187.4943   18 439.4919    FALSE
#> 16 3   EEE -179.4884   24 444.9812    FALSE
#> 17 4   VII -182.2114   23 446.8438    FALSE
#> 18 4   EII -189.0430   20 449.7565    FALSE
#> 19 4   VVV -120.4172   59 452.2620    FALSE
#> 20 3   VVI -179.7337   26 452.6388    FALSE
#> 21 4   EEI -185.1333   23 452.6875    FALSE
#> 22 3   VVV -149.2422   44 456.1591    FALSE
#> 23 4   EEE -176.5275   29 456.9771    FALSE
#> 24 4   VVI -173.6042   35 472.6316    FALSE
```
