# Guide to Idiographic Statistical Workflows

This document indexes the non-network statistical workflows in
`idiographic`. The package contains 16 major functions in this part of
its interface. They address different estimands: data quality,
within-person association, prediction, coefficient synthesis, subgroup
structure, and treatment-effect heterogeneity. Choosing a function
begins with the research question, not with the preferred algorithm.

## Start with the analytical question

| Question | Primary function | Detailed vignette |
|:---|:---|:---|
| Is each person’s series usable and sufficiently variable? | [`describe_persons()`](https://pak.dynasite.org/idiographic/reference/describe_persons.md) | [Person-level description](https://pak.dynasite.org/idiographic/articles/describe-persons.md) |
| How are variables associated within each person? | [`correlate_persons()`](https://pak.dynasite.org/idiographic/reference/correlate_persons.md) | [Within-person correlation](https://pak.dynasite.org/idiographic/articles/correlate-persons.md) |
| How much variation lies within versus between people? | [`variance_components()`](https://pak.dynasite.org/idiographic/reference/variance_components.md) | [Variance decomposition](https://pak.dynasite.org/idiographic/articles/variance-components.md) |
| How should a panel be ordered, lagged, centred, and screened? | [`preprocess_panel()`](https://pak.dynasite.org/idiographic/reference/preprocess_panel.md) | [Panel preparation](https://pak.dynasite.org/idiographic/articles/preprocess-panel.md) |
| What are the pooled and person-specific linear coefficients? | [`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md) | [Linear models](https://pak.dynasite.org/idiographic/articles/fit-lm.md) |
| What are the pooled and person-specific binary or count associations? | [`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md) | [Generalized linear models](https://pak.dynasite.org/idiographic/articles/fit-glm.md) |
| Which algorithm predicts later observations most accurately? | [`fit_ml()`](https://pak.dynasite.org/idiographic/reference/fit_ml.md) | [Machine learning](https://pak.dynasite.org/idiographic/articles/fit-ml.md) |
| Does predictive performance persist across forecast origins? | [`fit_rolling()`](https://pak.dynasite.org/idiographic/reference/fit_rolling.md) | [Rolling-origin validation](https://pak.dynasite.org/idiographic/articles/fit-rolling.md) |
| Do within-person and between-person effects differ? | [`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md) | [Within-between models](https://pak.dynasite.org/idiographic/articles/fit-within-between.md) |
| What is the uncertainty-weighted average of person-specific coefficients? | [`pool_coefs()`](https://pak.dynasite.org/idiographic/reference/pool_coefs.md) | [Coefficient pooling](https://pak.dynasite.org/idiographic/articles/pool-coefs.md) |
| How should noisy person-specific coefficients be stabilised? | [`shrink_coefs()`](https://pak.dynasite.org/idiographic/reference/shrink_coefs.md) | [Coefficient shrinkage](https://pak.dynasite.org/idiographic/articles/shrink-coefs.md) |
| Is a discrete subgroup representation supported at all? | [`test_subgroups()`](https://pak.dynasite.org/idiographic/reference/test_subgroups.md) | [Testing subgroup existence](https://pak.dynasite.org/idiographic/articles/test-subgroups.md) |
| Which people share a reproducible coefficient profile? | [`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md) | [Subgroup discovery](https://pak.dynasite.org/idiographic/articles/find-subgroups.md) |
| Does subgroup-specific modelling improve held-out performance? | [`fit_subgroups()`](https://pak.dynasite.org/idiographic/reference/fit_subgroups.md) | [Subgroup-specific models](https://pak.dynasite.org/idiographic/articles/fit-subgroups.md) |
| What is the treatment effect, and who benefits more? | [`fit_effects()`](https://pak.dynasite.org/idiographic/reference/fit_effects.md) | [Treatment effects](https://pak.dynasite.org/idiographic/articles/fit-effects.md) |
| Is a person-varying target predictably heterogeneous? | [`fit_heterogeneity()`](https://pak.dynasite.org/idiographic/reference/fit_heterogeneity.md) | [Repeated-split heterogeneity](https://pak.dynasite.org/idiographic/articles/fit-heterogeneity.md) |

## Recommended sequence

Most analyses should not begin with model fitting. The first four
functions establish whether the data support the intended estimand.

1.  Use
    [`describe_persons()`](https://pak.dynasite.org/idiographic/reference/describe_persons.md)
    to inspect usable observations, gaps, dispersion, successive change,
    autocorrelation, floor or ceiling concentration, and trends by
    person.
2.  Use
    [`variance_components()`](https://pak.dynasite.org/idiographic/reference/variance_components.md)
    to determine whether the target variation is primarily within people
    or between people. This decision changes the meaning of a pooled
    coefficient.
3.  Use
    [`correlate_persons()`](https://pak.dynasite.org/idiographic/reference/correlate_persons.md)
    for an initial description of contemporaneous within-person
    association. Do not interpret these correlations as lagged or causal
    effects.
4.  Use
    [`preprocess_panel()`](https://pak.dynasite.org/idiographic/reference/preprocess_panel.md)
    to make chronology, lags, centring, scaling, and missing-data
    consequences explicit before fitting a model.

The next function depends on the estimand. For a prespecified
coefficient, use
[`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md),
[`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md),
or
[`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md).
For future predictive performance, use
[`fit_ml()`](https://pak.dynasite.org/idiographic/reference/fit_ml.md)
and confirm temporal stability with
[`fit_rolling()`](https://pak.dynasite.org/idiographic/reference/fit_rolling.md).
For an intervention contrast, use
[`fit_effects()`](https://pak.dynasite.org/idiographic/reference/fit_effects.md);
prediction accuracy alone cannot identify a treatment effect.

## Coefficients: estimate, pool, or shrink

[`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md)
and
[`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md)
can estimate one model for the pooled panel, one per subgroup, one per
person, or several scopes together. The resulting person-specific
coefficients contain both genuine heterogeneity and sampling error. Two
downstream functions answer different questions.

- [`pool_coefs()`](https://pak.dynasite.org/idiographic/reference/pool_coefs.md)
  estimates the uncertainty-weighted average coefficient and quantifies
  residual between-person heterogeneity. Use it for population synthesis
  while retaining `tau` and I-squared.
- [`shrink_coefs()`](https://pak.dynasite.org/idiographic/reference/shrink_coefs.md)
  estimates a more stable coefficient for each person by moving
  imprecise values towards the pooled distribution. Use it for ranking,
  description, or downstream prediction when raw individual slopes are
  noisy.

Pooling does not assert that every person has the pooled effect.
Shrinkage does not erase heterogeneity. Both procedures require
comparable coefficients from models with the same outcome, predictors,
coding, and scale.

## Prediction: algorithm, scope, and time

[`fit_ml()`](https://pak.dynasite.org/idiographic/reference/fit_ml.md)
separates three decisions that are often conflated.

- **Algorithm:** linear, regularised, neighbour-based, tree-based, or an
  optional backend.
- **Scope:** pooled, subgroup, or individual.
- **Validation design:** which later observations form the validation
  and test blocks.

The [machine-learning
vignette](https://pak.dynasite.org/idiographic/articles/fit-ml.md)
compares models with a mean baseline, audits hyperparameter selection,
compares pooled and individual scopes, identifies people with poor
predictions, inspects their trajectories, and computes model-agnostic
permutation importance.
[`fit_rolling()`](https://pak.dynasite.org/idiographic/reference/fit_rolling.md)
extends the same logic across several temporal origins. A model should
not be called personally useful from an aggregate metric alone; report
the distribution of person-level errors.

## Subgroups: evidence before assignment

Subgroup work has three distinct stages.

1.  [`test_subgroups()`](https://pak.dynasite.org/idiographic/reference/test_subgroups.md)
    compares a one-population coefficient distribution with candidate
    finite mixtures. A one-group result is a valid conclusion.
2.  [`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md)
    assigns people only after a multi-group representation is defensible
    and reports resampling stability for every assignment.
3.  [`fit_subgroups()`](https://pak.dynasite.org/idiographic/reference/fit_subgroups.md)
    tests whether the resulting partition improves held-out modelling
    relative to pooled and individual alternatives.

A clustering algorithm always partitions the data when asked. This does
not prove that latent classes exist. Skewness, heavy tails, and
continuous heterogeneity can resemble discrete groups, so the BIC
comparison, shape diagnostics, stability, and out-of-sample utility
should be considered together.

## Effects and heterogeneity

[`fit_effects()`](https://pak.dynasite.org/idiographic/reference/fit_effects.md)
estimates an average treatment effect for a binary or multi-arm
treatment, or an average partial effect for a continuous dose. Its
sorted effect groups and heterogeneity slope ask whether the effect
differs systematically. These quantities require intervention-specific
identification assumptions, including treatment variation, overlap,
consistency, and adequate adjustment for confounding.

[`fit_heterogeneity()`](https://pak.dynasite.org/idiographic/reference/fit_heterogeneity.md)
generalises repeated-split heterogeneity analysis to a treatment effect,
prediction error, or gain from individualisation. It learns a proxy in
one sample and estimates grouped and linear heterogeneity in another.
Repeated splitting reduces dependence on one random partition but does
not create additional independent people.

## Reporting standard

A complete idiographic analysis should report the person identifier and
time ordering, observation counts and gaps by person, the exact outcome
and predictors, the model scope, preprocessing learned from training
data, the validation design, failed units, aggregate and person-level
results, and the assumptions that determine interpretation. Figures
should answer a named question: show uncertainty for coefficients and
effects, show a reference model for prediction, show chronology for
forecasts, and show assignment stability for subgroups.

The 16 linked vignettes provide executable examples using the bundled
`srl` data. Each example prints the public result object before
interpreting it, uses public accessors for detailed tables, and states
when a neighbouring function answers a more appropriate question.
