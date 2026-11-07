# Refresh recorded summaries/browser exports only; never fit models.
file_arg <- grep('^--file=',commandArgs(FALSE),value=TRUE)
if(length(file_arg)) setwd(normalizePath(file.path(dirname(sub('^--file=','',file_arg)),'..','..')))
stopifnot(requireNamespace('jsonlite',quietly=TRUE))
s <- read.csv('results/paper/scores.csv',stringsAsFactors=FALSE)
metrics <- c('MASE','MAE','RMSE')
keys <- do.call(paste,c(s[c('sensor','pollutant','horizon','method')],sep='|'))
stopifnot(!anyDuplicated(keys))
path <- 'results/paper/forecast_cache.rds'; old <- readRDS(path)
archive <- 'docs/audit/legacy_forecast_cache_2026-11-07.rds'
if(!file.exists(archive)) stopifnot(file.copy(path,archive,overwrite=FALSE))
cache <- setNames(vector('list',length(keys)),keys)
for(i in seq_along(keys)) {
  z <- old[[keys[i]]]
  if(is.null(z)) z <- as.list(s[i,c('sensor','pollutant','horizon','method')])
  compatible <- !is.null(z$yhat) && !is.null(z$scores) && all(vapply(metrics,function(m) isTRUE(abs(z$scores[[m]][1]-s[[m]][i])<1e-9),logical(1)))
  if(!compatible) { z$yhat<-NULL;z$lower<-NULL;z$upper<-NULL;z$unmatched_prediction_archive<-archive }
  z$error<-FALSE;z$scores<-s[i,metrics,drop=FALSE]
  z$score_source<-'results/paper/scores.csv';z$prediction_available<-compatible
  z$score_status<-if(compatible)'recorded_with_predictions' else 'recorded_summary_only'
  cache[[i]]<-z
}
saveRDS(cache,path)
write_js <- function(name,obj,file) writeLines(paste0('window.',name,'=',jsonlite::toJSON(obj,auto_unbox=TRUE,dataframe='rows',digits=NA,na='null',null='null'),';'),file,useBytes=TRUE)
web <- 'presentation/webapp/js/data'
write_js('SCORES',s[c('sensor','pollutant','horizon','method',metrics)],file.path(web,'scores.js'))
comparison <- read.csv('docs/audit/impact/C19_table1_vs_ours.csv',stringsAsFactors=FALSE)
columns <- c(xgb='ours_xgb',lgb='ours_lgb',catboost='ours_cat',wavecatboost='ours_wave')
for(i in seq_len(nrow(comparison))) for(method in names(columns)) {
  k<-paste(comparison$sensor[i],comparison$pollutant[i],comparison$horizon[i],method,sep='|')
  comparison[[columns[[method]]]][i]<-s$MASE[match(k,keys)]
}
write_js('PAPER_CMP',comparison,file.path(web,'paper_cmp.js'))
clip<-jsonlite::fromJSON(sub(';\\s*$','',sub('^[^=]*=','',paste(readLines(file.path(web,'clip.js')),collapse='\n'))))
p<-readRDS('results/paper/paper_protocol.rds')$CPCB;w<-p$methods$wavecatboost;sn<-p$methods$snaive
clip$protocol<-'paper-protocol rolling one-step; report Sections 8.1-8.2'
clip$source<-'results/paper/paper_protocol.rds'
clip$test<-list(t=format(p$t_test,'%d-%m-%Y %H:%M'),y=p$y_test,yhat_wavecatboost=w$yhat,yhat_snaive=sn$yhat,lower=w$lower,upper=w$upper,q95=mean(w$upper-w$lower)/2)
clip$metrics<-list(mase_wavecatboost=w$scores$MASE,mase_snaive=sn$scores$MASE,mae_wavecatboost=w$scores$MAE,mae_snaive=sn$scores$MAE,coverage=w$coverage_test,width=w$width)
write_js('CLIP',clip,file.path(web,'clip.js'))
cat('Synchronized',nrow(s),'recorded summaries and browser exports; no models fitted.\n')

# Refresh the retained rank summary from complete matched cases only.
suppressPackageStartupMessages(library(dplyr))
source('R/core/08_metrics.R')
wide <- tidyr::pivot_wider(s[c('sensor','pollutant','horizon','method','MASE')],names_from=method,values_from=MASE)
complete <- wide[stats::complete.cases(wide),c('sensor','pollutant','horizon')]
matched <- dplyr::semi_join(s,complete,by=c('sensor','pollutant','horizon'))
ranks <- mcb_from_table(matched)
saveRDS(ranks,'results/paper/mcb.rds')
write.csv(ranks,'results/paper/mcb.csv',row.names=FALSE)
