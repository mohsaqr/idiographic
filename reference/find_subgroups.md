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
be trusted. The printed result states this verdict; the BIC table
(`selection`) and the skewness diagnostic (`shape`) are stored in the
result.

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
auto
#> Idiographic Subgroups
#>   Method:      effect_clustering
#>   Subgroups:   1 (chosen automatically)
#>   People:      36
#>   Sizes:       g1=36
#>   Stability:   1.00 (how reproducible the partition is --
#>                NOT evidence that the subgroups are real)
#> 
#>   VERDICT:     no subgroups detected -- one population fits best.
#>                The groups above are not supported by the data.
#> 
#>   Use groups(), test_subgroups(), fit_subgroups()
```
