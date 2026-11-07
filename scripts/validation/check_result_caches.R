# No model fitting: verify CSV/RDS mirrors and recorded cache score summaries.
file_arg <- grep('^--file=', commandArgs(FALSE), value=TRUE)
if(length(file_arg)) setwd(normalizePath(file.path(dirname(sub('^--file=', '', file_arg)), '..', '..')))
metrics <- c('MASE','MAE','RMSE')
for (kind in c('paper/scores','extensions/filter_scores','extensions/extension_scores')) {
  a <- read.csv(paste0('results/', kind, '.csv'))
  b <- as.data.frame(readRDS(paste0('results/', kind, '.rds')))
  stopifnot(isTRUE(all.equal(a,b,check.attributes=FALSE,tolerance=1e-10)))
  cat('PASS CSV/RDS:', kind, nrow(a), 'rows\n')
}
s <- read.csv('results/paper/scores.csv')
x <- readRDS('results/paper/forecast_cache.rds')
keys <- do.call(paste,c(s[c('sensor','pollutant','horizon','method')],sep='|'))
stopifnot(setequal(keys,names(x)))
for(i in seq_len(nrow(s))) {
  z <- x[[keys[i]]]
  for(m in metrics) stopifnot(abs(s[[m]][i]-z$scores[[m]][1])<1e-9)
  if(isTRUE(z$prediction_available)) {
    stopifnot(!is.null(z$yhat),abs(mean(abs(z$y_test-z$yhat))-s$MAE[i])<1e-9)
  } else stopifnot(is.null(z$yhat),file.exists(z$unmatched_prediction_archive))
}
cat('PASS all',length(keys),'cache summaries match scores.csv; incompatible predictions are not attached.\n')
for(kind in c('filter','extension')) {
  s <- read.csv(paste0('results/extensions/',kind,'_scores.csv'))
  x <- readRDS(paste0('results/extensions/',kind,'_cache.rds'))
  for(i in seq_len(nrow(s))) {
    k <- paste(s[i,c('sensor','pollutant','horizon','method','filter')],collapse='|')
    for(m in metrics) stopifnot(abs(s[[m]][i]-x[[k]]$scores[[m]][1])<1e-9)
  }
  cat('PASS',kind,'scores and prediction cache summaries\n')
}
pp <- readRDS('results/paper/paper_protocol.rds')
clip <- jsonlite::fromJSON(sub(';\\s*$', '', sub('^[^=]*=', '', paste(readLines('presentation/webapp/js/data/clip.js'),collapse='\n'))))
z <- pp$CPCB;w <- z$methods$wavecatboost
stopifnot(max(abs(clip$test$yhat_wavecatboost-w$yhat))<1e-9,
          abs(clip$metrics$mae_wavecatboost-w$scores$MAE)<1e-9,
          abs(clip$metrics$mase_wavecatboost-w$scores$MASE)<1e-9)
cat('PASS browser forecast viewer matches report paper-protocol predictions.\n')

suppressPackageStartupMessages(library(dplyr))
source('R/core/08_metrics.R')
s<-read.csv('results/paper/scores.csv')
w<-tidyr::pivot_wider(s[c('sensor','pollutant','horizon','method','MASE')],names_from=method,values_from=MASE)
complete<-w[stats::complete.cases(w),c('sensor','pollutant','horizon')]
expected<-mcb_from_table(dplyr::semi_join(s,complete,by=c('sensor','pollutant','horizon')))
stopifnot(isTRUE(all.equal(as.data.frame(expected),read.csv('results/paper/mcb.csv'),check.attributes=FALSE,tolerance=1e-9)))
cat('PASS retained rank summary uses',nrow(complete),'complete matched cases. No rank plots added.\n')
