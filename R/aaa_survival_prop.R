#' A wrapper for survival probabilities with cph models
#' @param x A model from `coxph()`.
#' @param new_data Data for prediction
#' @param .times A vector of integers for prediction times.
#' @param output One of "surv", "conf", or "haz".
#' @param conf.int The confidence level
#' @param ... Options to pass to [survival::survfit()]
#' @return A nested tibble
#' @keywords internal
#' @export
cph_survival_prob <- function(x, new_data, .times, output = "surv", conf.int = .95, ...) {
  output <- match.arg(output, c("surv", "conf", "haz"))
  y <- survival::survfit(x, newdata = new_data, conf.int = conf.int,
                         na.action = na.exclude, ...)
  res <-
    stack_survfit(y, nrow(new_data)) %>%
    dplyr::group_nest(.row, .key = ".pred") %>%
    mutate(
      .pred = purrr::map(.pred, ~ dplyr::bind_rows(prob_template, .x)),
      .pred = purrr::map(.pred, interpolate_km_values, .times)
    )

  keep_cols(res, output)
}

keep_cols <- function(x, output) {
  if (output == "surv") {
    x <- dplyr::mutate(x,
                       .pred =
                         purrr::map(.pred,
                                    ~ dplyr::select(.x, .time, .pred_survival)))
  } else if (output == "conf") {
    x <- dplyr::mutate(x,
                       .pred =
                         purrr::map(.pred,
                                    ~ dplyr::select(.x, .time, .pred_survival_lower,
                                                    .pred_survival_upper)))
  } else {
    x <- dplyr::mutate(x,
                       .pred =
                         purrr::map(.pred,
                                    ~ dplyr::select(.x, .time, .pred_hazard_cumulative)))
  }
  dplyr::select(x, -.row)
}

stack_survfit <- function(x, n) {
  # glmnet does not calculate confidence intervals
  if (is.null(x$lower)) x$lower <- NA_real_
  if (is.null(x$upper)) x$upper <- NA_real_

  has_strata <- any(names(x) == "strata")

  if (has_strata) {
    # All components are vectors of length {t_i x n}
    res <- tibble::tibble(
      .time = x$time,
      .pred_survival = x$surv,
      .pred_survival_lower = x$lower,
      .pred_survival_upper = x$upper,
      .pred_hazard_cumulative = x$cumhaz,
      .row = rep(seq_len(n), x$strata)
    )
  } else {
    # All components are {t x n} matrices
    times <- length(x$time)
    res <- tibble::tibble(
      .time = rep(x$time, n),
      .pred_survival = as.vector(x$surv),
      .pred_survival_lower = as.vector(x$lower),
      .pred_survival_upper = as.vector(x$upper),
      .pred_hazard_cumulative = as.vector(x$cumhaz),
      .row = rep(seq_len(n), each = times)
    )
  }

  res
}

prob_template <- tibble::tibble(
  .time = 0,
  .pred_survival = 1,
  .pred_survival_lower = NA_real_,
  .pred_survival_upper = NA_real_,
  .pred_hazard_cumulative = 0
)

# We want to maintain the step-function aspect of the predictions so, rather
# than use `approx()`, we cut the times and match the new times based on these
# intervals.
interpolate_km_values <- function(x, .times) {
  x <- km_with_cuts(x)
  pred_times <-
    tibble::tibble(.time = .times) %>%
    km_with_cuts(.times = x$.time) %>%
    dplyr::rename(.tmp = .time) %>%
    dplyr::left_join(x, by = ".cuts") %>%
    dplyr::select(-.time, .time = .tmp, -.cuts)
  pred_times
}

km_with_cuts <- function(x, .times = NULL) {
  if (is.null(.times)) {
    # When cutting the original data in the survfit object
    .times <- unique(x$.time)
  }
  .times <- c(-Inf, .times, Inf)
  .times <- unique(.times)
  x$.cuts <- cut(x$.time, .times)
  x
}

cph_survival_pre <- function(new_data, object) {

  # Check that the stratification variable is part of `new_data`.
  # If this information is missing, survival::survfit() does not error but
  # instead returns the survival curves for _all_ strata.
  terms_x <- stats::terms(object$fit)
  terms_special <- attr(terms_x, "specials")
  has_strata <- !is.null(terms_special$strata)

  if (has_strata) {
    strata <- attr(terms_x, "term.labels")
    strata <- grep(pattern = "^strata", x = strata, value = TRUE)
    strata <- sub(pattern = "strata\\(", replacement = "", x = strata)
    strata <- sub(pattern = "\\)", replacement = "", x = strata)

    if (!strata %in% names(new_data)) {
      rlang::abort("Please provide the strata variable in `new_data`.")
    }
  }

  new_data
}

#' A wrapper for survival probabilities with coxnet models
#' @param x A model from `glmnet()`.
#' @param new_data Data for prediction
#' @param .times A vector of integers for prediction times.
#' @param training_data A list of `x` and `y` containing the training data.
#' @param output One of "surv" or "haz".
#' @param ... Options to pass to [survival::survfit()]
#' @return A nested tibble
#' @keywords internal
#' @export
coxnet_survival_prob <- function(x, new_data, .times, training_data, output = "surv", ...) {
  output <- match.arg(output, c("surv", "haz"))

  y <- survival::survfit(x,
                         newx = as.matrix(new_data), # newstrata
                         x = training_data$x, y = training_data$y,
                         na.action = na.exclude, ...)
  res <-
    stack_survfit(y, nrow(new_data)) %>%
    dplyr::group_nest(.row, .key = ".pred") %>%
    mutate(
      .pred = purrr::map(.pred, ~ dplyr::bind_rows(prob_template, .x)),
      .pred = purrr::map(.pred, interpolate_km_values, .times)
    )

  keep_cols(res, output)
}
