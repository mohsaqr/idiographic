#' Self-regulated learning intensive longitudinal data (Chapter 20)
#'
#' The self-regulated learning (SRL) experience-sampling data used in the
#' Learning Analytics Methods book, Chapter 20 (Vector Autoregression). Each of
#' 36 students reported nine self-regulated-learning indicators once per study
#' occasion for 156 occasions, giving a balanced person-by-time panel suitable
#' for the idiographic time-series methods in this package.
#'
#' The columns have already been tidied for modelling: rows are ordered by
#' `name` then `day`, and `day` is a within-person occasion index (1-156) you can
#' pass as the `time` argument to [fit_usem()] and [fit_gimme()]. No further
#' ordering, indexing, or column selection is needed before fitting a model.
#'
#' @format A `data.frame` with 5616 rows and 11 columns:
#' \describe{
#'   \item{name}{Student name (36 unique students).}
#'   \item{day}{Within-person occasion index, 1-156.}
#'   \item{efficacy}{Self-efficacy.}
#'   \item{value}{Task value.}
#'   \item{planning}{Planning.}
#'   \item{monitoring}{Monitoring.}
#'   \item{effort}{Effort regulation.}
#'   \item{control}{Control of learning.}
#'   \item{help}{Help seeking.}
#'   \item{social}{Social support.}
#'   \item{organizing}{Organizing.}
#' }
#' @source Learning Analytics Methods, Book 2, Chapter 20 (VAR):
#'   \url{https://lamethods.org/book2/chapters/ch20-var/ch20-var.html}. Original
#'   data: \url{https://github.com/lamethods/data2/raw/main/srl/srl.RDS},
#'   licensed under CC BY-NC-SA 4.0. See the package `COPYRIGHTS` file for
#'   attribution and transformation details.
#' @examples
#' data(srl)
#' summary(srl)
#' head(srl)
"srl"

#' Momentary self-regulated-learning experience-sampling data
#'
#' An anonymized intensive longitudinal data set in which 41 students rated
#' their momentary self-regulation, motivation, and anxiety several times per
#' day over the course of a study, giving roughly 70 to 80 occasions each. Unlike
#' the once-per-day [srl] panel, the occasions here are within-day momentary
#' assessments, so the series are well suited to person-specific (idiographic)
#' VAR, graphical VAR, and unified SEM. The data are fully anonymized: the
#' participant identifiers are fictional names, and the calendar dates have been
#' shifted by a constant offset (preserving all within-person spacing) so that
#' no real dates or identities remain.
#'
#' The nine indicators span three domains: self-regulation (`planning`,
#' `monitoring`, `effort`, `regulation`), motivation (`efficacy`, `value`,
#' `motivated`, `enjoyment`), and `anxiety`. Each variable is on a 0-100 scale.
#' Rows are one person-occasion each, ordered within person by `occasion`.
#'
#' @format A `data.frame` with 2820 rows and 12 columns:
#' \describe{
#'   \item{name}{Fictional participant identifier (41 unique students).}
#'   \item{occasion}{Within-person occasion index, ordered in time.}
#'   \item{date}{Anonymized (constant-shifted) assessment date.}
#'   \item{efficacy}{Momentary self-efficacy (motivation).}
#'   \item{value}{Momentary task value (motivation).}
#'   \item{planning}{Momentary planning (self-regulation).}
#'   \item{monitoring}{Momentary monitoring (self-regulation).}
#'   \item{effort}{Momentary effort regulation (self-regulation).}
#'   \item{regulation}{Momentary strategy regulation (self-regulation).}
#'   \item{motivated}{Momentary felt motivation (motivation).}
#'   \item{enjoyment}{Momentary enjoyment (motivation).}
#'   \item{anxiety}{Momentary anxiety.}
#' }
#' @examples
#' data(esm_srl)
#' summary(esm_srl)
#' head(esm_srl)
"esm_srl"
