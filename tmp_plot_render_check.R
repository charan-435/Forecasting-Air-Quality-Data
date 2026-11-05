library(plotly)
library(shiny)
library(dplyr)
library(tibble)
library(ggplot2)
source_text <- readLines("analysis.Rmd", encoding = "UTF-8")
chunk <- function(label) {
  start <- grep(paste0("^\\x60{3}\\{r ", label, "[,}]"), source_text)
  stopifnot(length(start) == 1)
  end <- start + which(source_text[(start + 1):length(source_text)] == "\x60\x60\x60")[1]
  parse(text = source_text[(start + 1):(end - 1)])
}
parsed_path <- tempfile(fileext = ".R")
knitr::purl("analysis.Rmd", output = parsed_path, documentation = 0, quiet = TRUE)
invisible(parse(file = parsed_path))
helpers <- c("panel_h", "stack_px", "line_panel", "stack_panels", "plotly_slot")
for (expr in chunk("setup")) {
  if (is.call(expr) && identical(expr[[1]], as.name("<-")) &&
      as.character(expr[[2]]) %in% helpers) eval(expr)
}
NAVY <- "#1F3A5F"
RUST <- "#A64B2A"
GREEN <- "#2E6B4F"
x <- as.POSIXct("2023-01-01", tz = "UTC") + seq_len(240) * 3600
y <- 20 + sin(seq_along(x) / 8)
captured_warnings <- captured_messages <- character()
withCallingHandlers({
  for (n in c(4L, 7L)) {
    panels <- lapply(seq_len(n), function(i) line_panel(x, y, "test", NAVY, "PM2.5",
                                                       height = stack_px(n)))
    built <- plotly_build(stack_panels(panels, paste("Panel", seq_len(n)), n))
    stopifnot(built$height == stack_px(n), built$x$layout$height == stack_px(n),
              length(built$x$data) == n)
  }
  paper8 <- list(CPCB = list(
    methods = list(wavecatboost = list(yhat = y, lower = y - 2, upper = y + 2,
                                       coverage_test = 0.95, width = 4)),
    t_test = x, y_test = y))
  testServer(function(input, output, session) {
    s_re <- reactive(list(times = x, y = y))
    split_re <- reactive(list(y_train = y))
    eval(chunk("eda-full-server"))
    eval(chunk("eda-scatter-server"))
    eval(chunk("s8-conf-server"))
    session$setInputs(sensor = "CPCB", pollutant = "PM2.5", lagk = 1L)
  }, {
    session$flushReact()
    stopifnot(!is.null(output$full_plot), !is.null(output$scatter_plot))
    for (name in c("CPCB", "missing")) {
      built <- plotly_build(.s8_conf_fig(name, "a"))
      stopifnot(built$height == stack_px(1L), built$x$layout$height == stack_px(1L))
    }
  })
  p <- ggplot(data.frame(filter = rep(c("Haar", "D4", "LA8"), 2),
                          MASE = 1:6 / 3, sensor = rep(c("CPCB", "ID1"), each = 3)),
              aes(filter, MASE, fill = filter)) +
    geom_col() + facet_wrap(~sensor)
  built <- plotly_build(ggplotly(p, height = stack_px(2L)) %>%
                         layout(autosize = TRUE))
  stopifnot(built$height == stack_px(2L))
}, warning = function(w) {
  captured_warnings <<- c(captured_warnings, conditionMessage(w))
  invokeRestart("muffleWarning")
}, message = function(m) {
  captured_messages <<- c(captured_messages, conditionMessage(m))
  invokeRestart("muffleMessage")
})
stopifnot(!any(grepl("Specifying width/height|deprecated", captured_warnings)),
          !any(grepl("geom_smooth.*formula", captured_messages)))
cat("Verified plot heights, stacked panels, full-series/scatter renderers, interval and empty-state plots, and filter facets.\n")
if (length(captured_warnings)) {
  cat("Other warnings:\n")
  cat(unique(captured_warnings), sep = "\n")
}
