#' Feature Tranformation -- ChiSqSelector (Estimator)
#'
#' Chi-Squared feature selection, which selects categorical features to use for predicting a categorical label
#'
#' @param output_col The name of the output column.
#' @template roxlate-ml-feature-transformer
#' @template roxlate-ml-feature-estimator-transformer
#' @param fdr (Spark 2.2.0+) The upper bound of the expected false discovery rate. Only applicable when selector_type = "fdr". Default value is 0.05.
#' @template roxlate-ml-features-col
#' @param fpr (Spark 2.1.0+) The highest p-value for features to be kept. Only applicable when selector_type= "fpr". Default value is 0.05.
#' @param fwe (Spark 2.2.0+) The upper bound of the expected family-wise error rate. Only applicable when selector_type = "fwe". Default value is 0.05.
#' @template roxlate-ml-label-col
#' @param num_top_features Number of features that selector will select, ordered by ascending p-value. If the number of features is less than \code{num_top_features}, then this will select all features. Only applicable when selector_type = "numTopFeatures". The default value of \code{num_top_features} is 50.
#' @param percentile (Spark 2.1.0+) Percentile of features that selector will select, ordered by statistics value descending. Only applicable when selector_type = "percentile". Default value is 0.1.
#' @param selector_type (Spark 2.1.0+) The selector type of the ChisqSelector. Supported options: "numTopFeatures" (default), "percentile", "fpr", "fdr", "fwe".
#'
#'
#' @export
ft_chisq_selector <- function(
  x, features_col, output_col, label_col, selector_type = "numTopFeatures",
  fdr = 0.05, fpr = 0.05, fwe = 0.05, num_top_features = 50L, percentile = 0.1,
  dataset = NULL,
  uid = random_string("chisq_selector_"), ...) {
  UseMethod("ft_chisq_selector")
}

#' @export
ft_chisq_selector.spark_connection <- function(
  x, features_col, output_col, label_col, selector_type = "numTopFeatures",
  fdr = 0.05, fpr = 0.05, fwe = 0.05, num_top_features = 50L, percentile = 0.1,
  dataset = NULL,
  uid = random_string("chisq_selector_"), ...) {

  ml_ratify_args()

  estimator <- invoke_new(x, "org.apache.spark.ml.feature.ChiSqSelector", uid) %>%
    jobj_set_param("setFdr", fdr, 0.05, "2.2.0") %>%
    invoke("setFeaturesCol", features_col) %>%
    jobj_set_param("setFpr", fpr, 0.05, "2.1.0") %>%
    jobj_set_param("setFwe", fwe, 0.05, "2.2.0") %>%
    invoke("setLabelCol", label_col) %>%
    invoke("setNumTopFeatures", num_top_features) %>%
    invoke("setOutputCol", output_col) %>%
    jobj_set_param("setPercentile", percentile, 0.1, "2.1.0") %>%
    jobj_set_param("setSelectorType", selector_type, "numTopFeatures", "2.1.0") %>%
    new_ml_chisq_selector()

  if (is.null(dataset))
    estimator
  else
    ml_fit(estimator, dataset)
}

#' @export
ft_chisq_selector.ml_pipeline <- function(
  x, features_col, output_col, label_col, selector_type = "numTopFeatures",
  fdr = 0.05, fpr = 0.05, fwe = 0.05, num_top_features = 50L, percentile = 0.1,
  dataset = NULL,
  uid = random_string("chisq_selector_"), ...
) {

  stage <- ml_new_stage_modified_args()
  ml_add_stage(x, stage)

}

#' @export
ft_chisq_selector.tbl_spark <- function(
  x, features_col, output_col, label_col, selector_type = "num_top_features",
  fdr = 0.05, fpr = 0.05, fwe = 0.05, num_top_features = 50L, percentile = 0.1,
  dataset = NULL,
  uid = random_string("chisq_selector_"), ...
) {
  dots <- rlang::dots_list(...)

  stage <- ml_new_stage_modified_args()

  if (is_ml_transformer(stage))
    ml_transform(stage, x)
  else
    ml_fit_and_transform(stage, x)
}

new_ml_chisq_selector <- function(jobj) {
  new_ml_estimator(jobj, subclass = "ml_chisq_selector")
}

new_ml_chisq_selector_model <- function(jobj) {
  new_ml_transformer(jobj, subclass = "ml_chisq_selector_model")
}

ml_validator_chisq_selector <- function(args, nms) {
  args %>%
    ml_validate_args({
      features_col <- ensure_scalar_character(features_col)
      label_col <- ensure_scalar_character(label_col)
      output_col <- ensure_scalar_character(output_col)
      fdr <- ensure_scalar_double(fdr)
      fpr <- ensure_scalar_double(fpr)
      fwe <- ensure_scalar_double(fwe)
      num_top_features <- ensure_scalar_integer(num_top_features)
      percentile <- ensure_scalar_double(percentile)
      selector_type <- rlang::arg_match(
        selector_type,
        c("numTopFeatures", "percentile", "fpr", "fdr", "fwe"))
      uid <- ensure_scalar_character(uid)
    }) %>%
    ml_extract_args(nms)
}
