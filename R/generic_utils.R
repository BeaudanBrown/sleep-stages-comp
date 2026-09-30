strip_lm <- function(cm) {
  cm$y <- c()
  cm$model <- c()
  cm$residuals <- c()
  cm$fitted.values <- c()
  cm$effects <- c()
  cm$linear.predictors <- c()
  cm$weights <- c()
  cm$prior.weights <- c()
  cm$data <- c()

  cm
}
