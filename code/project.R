# Locate the checkout from the root, the R report, or a nested code folder.
# All data and result paths are anchored here, rather than to a user's drive.
find_project_root <- function(start = getwd()) {
  candidate <- normalizePath(start, winslash = "/", mustWork = TRUE)
  repeat {
    if (dir.exists(file.path(candidate, "code", "R")) &&
        dir.exists(file.path(candidate, "data", "raw"))) return(candidate)
    parent <- dirname(candidate)
    if (identical(parent, candidate)) stop("Cannot locate the project. Open the checkout containing code/ and data/.")
    candidate <- parent
  }
}
PROJECT_ROOT <- find_project_root()

# YAML files are UTF-8 even when the local R session uses an ASCII locale.
read_project_yaml <- function(path) {
  text <- paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  yaml::yaml.load(text, error.label = path)
}
