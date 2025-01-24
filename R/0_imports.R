#' @importFrom rlang enquo expr enquos call2 eval_tidy new_quosure empty_env
#' @importFrom purrr map_lgl map_dbl map
#' @importFrom tibble is_tibble as_tibble tibble
#' @importFrom parsnip set_new_model new_model_spec update_dot_check null_value
#' @importFrom parsnip set_encoding set_model_arg eval_args
#' @importFrom parsnip predict.model_fit predict_survival predict_survival.model_fit
#' @importFrom parsnip translate model_printer translate.default
#' @importFrom parsnip update_engine_parameters check_final_param
#' @importFrom parsnip update_main_parameters show_call
#' @importFrom withr with_options
#' @importFrom stats predict approx quantile na.pass na.exclude
#' @importFrom survival strata untangle.specials
#' @importFrom dials new_quant_param
#' @importFrom tidyr pivot_longer gather
#' @importFrom dplyr group_nest %>% arrange
#' @importFrom baguette bag_tree
#' @importFrom utils getFromNamespace
#' @importFrom generics fit

utils::globalVariables(
  c(".time", "object", "new_data", ".label", ".pred",
    ".cuts", ".id", ".pred_hazard_cumulative", ".tmp")
)

# ------------------------------------------------------------------------------

# The functions below define the model information. These access the model
# environment inside of parsnip so they have to be executed once parsnip has
# been loaded.

.onLoad <- function(libname, pkgname) {

  make_proportional_hazards_survival()
  make_proportional_hazards_glmnet()

  make_boost_tree_mboost()

  make_decision_tree_rpart()
  make_decision_tree_party()

  make_bag_tree_ipred()

  make_rand_forest_party()

  make_survival_reg_survival()
  make_survival_reg_flexsurv()

}
