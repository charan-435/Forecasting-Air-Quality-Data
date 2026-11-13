# Highlight comparable measured scores in HTML report tables.
best_kable <- function(data, columns, groups = character(), by_row = FALSE,
                        maximize = character(), digits = 3, caption = NULL) {
  columns <- intersect(columns, names(data))
  formatted <- data
  for (column in columns) {
    formatted[[column]] <- ifelse(is.finite(data[[column]]),
                                   formatC(data[[column]], format = "f", digits = digits), NA_character_)
  }
  highlight <- function(rows, column, best) {
    values <- data[[column]][rows]
    selected <- rows[is.finite(values) & abs(values - best) <= max(1e-12, abs(best) * 1e-10)]
    formatted[[column]][selected] <<- paste0("<strong>", formatted[[column]][selected], "</strong>")
  }
  if (by_row) {
    for (row in seq_len(nrow(data))) {
      values <- as.numeric(unlist(data[row, columns, drop = FALSE]))
      if (!any(is.finite(values))) next
      best <- min(values[is.finite(values)])
      for (column in columns) highlight(row, column, best)
    }
  } else {
    row_groups <- list(seq_len(nrow(data)))
    if (length(groups)) row_groups <- split(seq_len(nrow(data)), interaction(data[groups], drop = TRUE))
    for (rows in row_groups) for (column in columns) {
      values <- data[[column]][rows]
      if (!any(is.finite(values))) next
      best <- if (column %in% maximize) max(values[is.finite(values)]) else min(values[is.finite(values)])
      highlight(rows, column, best)
    }
  }
  alignment <- ifelse(vapply(data, is.numeric, logical(1)), "r", "l")
  table <- knitr::kable(formatted, format = "html", escape = FALSE, align = alignment,
                         digits = digits, caption = caption)
  structure(paste0('<div class="result-table">', paste(table, collapse = "\n"), '</div>'),
              class = "knitr_kable", format = "html")
}
