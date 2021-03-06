ml_print_uid <- function(x) cat(paste0("<", x$uid, ">"), "\n")

ml_print_class <- function(x, type) {
  type <- if (is_ml_estimator(x))
    "Estimator"
  else if (is_ml_transformer(x))
    "Transformer"
  else
    class(x)[1]
  cat(ml_short_type(x), paste0("(", type, ")\n"))
}

ml_print_column_name_params <- function(x) {
  cat(" (Parameters -- Column Names)\n")
  out_names <- ml_param_map(x) %>%
    names() %>%
    grep("col|cols$", ., value = TRUE)
  for (param in sort(out_names))
    cat(paste0("  ", param, ": ",
               paste0(ml_param(x, param), collapse = ", "),
               "\n"))
}

ml_print_params <- function(x) {
  cat(" (Parameters)\n")
  out_names <- ml_param_map(x) %>%
    names() %>%
    grep(".*(?<!col|cols)$", ., value = TRUE, perl = TRUE)
  for (param in sort(out_names))
    cat(paste0("  ", param, ": ", ml_param(x, param), "\n"))
}

ml_print_transformer_info <- function(x) {
  items <- names(x) %>%
      setdiff(c("uid", "param_map", "summary", ".jobj")) %>%
      grep(".*(?<!col|cols)$", ., value = TRUE, perl = TRUE)
  if (length(Filter(length, x[items]))) {
    cat(" (Transformer Info)\n")
    for (item in sort(items))
      if (!rlang::is_null(x[[item]]))
        if (rlang::is_atomic(x[[item]])) {
          cat(paste0("  ", item, ": ", capture.output(str(x[[item]]))), "\n")
        } else
          cat(paste0("  ", item, ": <", class(x[[item]])[1], ">"), "\n")
  }
}

print_newline <- function() {
  cat("", sep = "\n")
}

ml_model_print_call <- function(model) {
  printf("Call: %s\n", model$.call)
  invisible(model$.call)
}

ml_model_print_residuals <- function(model,
                                     residuals.header = "Residuals") {

  residuals <- model$summary$residuals %>%
    (function(x) if (is.function(x)) x() else x) %>%
    spark_dataframe()

  # randomly sample residuals and produce quantiles based on
  # sample to avoid slowness in Spark's 'percentile_approx()'
  # implementation
  count <- invoke(residuals, "count")
  limit <- 1E5
  isApproximate <- count > limit
  column <- invoke(residuals, "columns")[[1]]

  values <- if (isApproximate) {
    fraction <- limit / count
    residuals %>%
      invoke("sample", FALSE, fraction) %>%
      sdf_read_column(column) %>%
      quantile()
  } else {
    residuals %>%
      sdf_read_column(column) %>%
      quantile()
  }
  names(values) <- c("Min", "1Q", "Median", "3Q", "Max")

  header <- if (isApproximate)
    paste(residuals.header, "(approximate):")
  else
    paste(residuals.header, ":", sep = "")

  cat(header, sep = "\n")
  print(values, digits = max(3L, getOption("digits") - 3L))
  invisible(values)
}

#' @importFrom stats coefficients quantile
ml_model_print_coefficients <- function(model) {

  coef <- coefficients(model)

  cat("Coefficients:", sep = "\n")
  print(coef)
  invisible(coef)
}

ml_model_print_coefficients_detailed <- function(model) {

  # extract relevant columns for stats::printCoefmat call
  # (protect against routines that don't provide standard
  # error estimates, etc)
  columns <- c("coefficients", "standard.errors", "t.values", "p.values")
  values <- as.list(model[columns])
  for (value in values)
    if (is.null(value))
      return(ml_model_print_coefficients(model))

  matrix <- do.call(base::cbind, values)
  colnames(matrix) <- c("Estimate", "Std. Error", "t value", "Pr(>|t|)")

  cat("Coefficients:", sep = "\n")
  stats::printCoefmat(matrix)
}

ml_model_print_centers <- function(model) {

  centers <- model$centers
  if (is.null(centers))
    return()

  cat("Cluster centers:", sep = "\n")
  print(model$centers)

}


#' Spark ML - Feature Importance for Tree Models
#'
#' @param model A decision tree-based \code{ml_model}
#' @template roxlate-ml-dots
#'
#' @return A sorted data frame with feature labels and their relative importance.
#' @export
ml_tree_feature_importance <- function(model, ...)
{
  # backwards compat, old signature was function(sc, model)
  if (inherits(model, "spark_connection"))
    model <- rlang::dots_list(...) %>% unlist()

  supported <- grepl(
    "ml_model_decision_tree|ml_model_gbt|ml_model_random_forest",
    class(model)[1])

  if (!supported)
    stop("ml_tree_feature_importance() not supported for ", class(model)[1])

  # enforce Spark 2.0.0 for certain models
  requires_spark_2 <- grepl(
    "ml_model_decision_tree|ml_model_gbt",
    class(model)[1])

  if (requires_spark_2)
    spark_require_version(spark_connection(spark_jobj(model)), "2.0.0")

  model$model$feature_importances %>%
    cbind(model$.features, .) %>%
    as.data.frame() %>%
    rlang::set_names(c("feature", "importance")) %>%
    dplyr::arrange(dplyr::desc(!!rlang::sym("importance")))
}
