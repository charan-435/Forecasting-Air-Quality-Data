# Feature selection and dimensionality reduction (Phase 2, Stage C).
# Every transform follows the R/41 contract: fit(X_fit, y_fit) sees only the
# fitting rows (train for selection, train + validation for the frozen refit)
# and returns apply(X), used unchanged on later rows. Hyperparameters (k,
# components, penalty) are chosen on validation by the caller and passed in
# frozen. `info` records what was fitted, for stability reports.

.mv_check_cols <- function(X, cols) {
  miss <- setdiff(cols, colnames(X))
  if (length(miss)) stop("columns not in X: ", paste(head(miss, 5), collapse = ", "))
  cols
}

# Fixed column subset (pollutant ablations, RFE result). Nothing is fitted.
mv_transform_columns <- function(cols, name = "columns") {
  force(cols)
  list(name = name, fit = function(X_fit, y_fit = NULL) {
    .mv_check_cols(X_fit, cols)
    list(name = name, info = list(selected = cols),
         apply = function(X) X[, cols, drop = FALSE])
  })
}

# Columns of the named pollutants (all lags), keeping the global column order.
mv_pollutant_columns <- function(feature_names, pollutants) {
  feature_names[sub("__lag[0-9]+$", "", feature_names) %in% pollutants]
}

# Rank by |Pearson correlation with y| on the fitting rows; keep the top k.
mv_transform_corr_topk <- function(k) {
  force(k)
  list(name = paste0("corr_top", k), fit = function(X_fit, y_fit) {
    if (is.null(y_fit)) stop("corr selection needs y")
    r <- suppressWarnings(abs(stats::cor(X_fit, y_fit)[, 1]))
    r[!is.finite(r)] <- 0
    keep <- colnames(X_fit)[order(-r, seq_along(r))][seq_len(min(k, ncol(X_fit)))]
    keep <- colnames(X_fit)[colnames(X_fit) %in% keep]          # original order
    list(name = paste0("corr_top", k), info = list(selected = keep, score = r),
         apply = function(X) X[, keep, drop = FALSE])
  })
}

# Mutual information with y from equal-frequency bins fitted on the fitting rows.
mv_mutual_info <- function(X, y, bins = 16L) {
  qb <- function(v) {
    br <- unique(stats::quantile(v, seq(0, 1, length.out = bins + 1L), names = FALSE, type = 7))
    if (length(br) < 2L) return(rep(1L, length(v)))
    findInterval(v, br, rightmost.closed = TRUE, all.inside = TRUE)
  }
  by <- qb(y)
  py <- tabulate(by) / length(by)
  vapply(seq_len(ncol(X)), function(j) {
    bx <- qb(X[, j])
    tab <- table(bx, by) / length(by)
    px <- rowSums(tab)
    nz <- tab > 0
    sum(tab[nz] * log(tab[nz] / outer(px, py)[nz]))
  }, numeric(1))
}

mv_transform_mi_topk <- function(k, bins = 16L) {
  force(k)
  list(name = paste0("mi_top", k), fit = function(X_fit, y_fit) {
    if (is.null(y_fit)) stop("MI selection needs y")
    s <- stats::setNames(mv_mutual_info(X_fit, y_fit, bins), colnames(X_fit))
    keep <- names(s)[order(-s, seq_along(s))][seq_len(min(k, ncol(X_fit)))]
    keep <- colnames(X_fit)[colnames(X_fit) %in% keep]
    list(name = paste0("mi_top", k), info = list(selected = keep, score = s),
         apply = function(X) X[, keep, drop = FALSE])
  })
}

# Elastic-net selection: refit EN at a frozen (alpha, lambda) on standardized
# fitting rows and keep columns with non-zero coefficients.
mv_transform_enet_select <- function(alpha, lambda) {
  force(alpha); force(lambda)
  list(name = "enet_select", fit = function(X_fit, y_fit) {
    st <- mv_transform_standardize()$fit(X_fit)
    m <- glmnet::glmnet(st$apply(X_fit), y_fit, alpha = alpha, lambda = lambda,
                        standardize = FALSE, control = list(maxit = 1e6))
    b <- as.numeric(stats::coef(m))[-1]
    keep <- colnames(X_fit)[b != 0]
    if (!length(keep)) keep <- colnames(X_fit)[which.max(abs(stats::cor(X_fit, y_fit)[, 1]))]
    list(name = "enet_select", info = list(selected = keep, coef = stats::setNames(b, colnames(X_fit))),
         apply = function(X) X[, keep, drop = FALSE])
  })
}

# PCA on standardized fitting rows; returns the first k component scores.
mv_transform_pca <- function(k) {
  force(k)
  list(name = paste0("pca", k), fit = function(X_fit, y_fit = NULL) {
    st <- mv_transform_standardize()$fit(X_fit)
    pc <- stats::prcomp(st$apply(X_fit), center = FALSE, scale. = FALSE, rank. = k)
    R <- pc$rotation[, seq_len(min(k, ncol(pc$rotation))), drop = FALSE]
    ve <- pc$sdev^2 / sum(pc$sdev^2)
    list(name = paste0("pca", k),
         info = list(k = ncol(R), var_explained = ve[seq_len(ncol(R))],
                     cum_var = sum(ve[seq_len(ncol(R))]), rotation = R),
         apply = function(X) {
           Z <- st$apply(X) %*% R
           colnames(Z) <- paste0("PC", seq_len(ncol(Z)))
           Z
         })
  })
}

# PLS (SIMPLS) on standardized fitting rows; returns the first k score columns.
mv_transform_pls <- function(k) {
  force(k)
  list(name = paste0("plsscores", k), fit = function(X_fit, y_fit) {
    st <- mv_transform_standardize()$fit(X_fit)
    Z <- st$apply(X_fit)
    m <- pls::plsr(y ~ Z, ncomp = k, data = list(y = y_fit, Z = Z), method = "simpls",
                   scale = FALSE, validation = "none")
    W <- unclass(m$projection)[, seq_len(k), drop = FALSE]
    xm <- colMeans(Z)
    list(name = paste0("plsscores", k), info = list(k = k, projection = W),
         apply = function(X) {
           S <- sweep(st$apply(X), 2, xm, "-") %*% W
           colnames(S) <- paste0("PLS", seq_len(ncol(S)))
           S
         })
  })
}

# Compose two transforms: second is fitted on the output of the first.
mv_transform_chain <- function(a, b) {
  list(name = paste(a$name, b$name, sep = "+"), fit = function(X_fit, y_fit = NULL) {
    fa <- a$fit(X_fit, y_fit)
    fb <- b$fit(fa$apply(X_fit), y_fit)
    list(name = paste(a$name, b$name, sep = "+"), info = c(fa$info, fb$info),
         apply = function(X) fb$apply(fa$apply(X)))
  })
}

mv_jaccard <- function(a, b) if (!length(union(a, b))) NA_real_ else
  length(intersect(a, b)) / length(union(a, b))

# Aggregate a per-feature importance vector to pollutant shares.
mv_importance_by_pollutant <- function(imp) {
  if (!length(imp)) return(NULL)
  p <- sub("__lag[0-9]+$", "", names(imp))
  s <- tapply(imp, p, sum)
  s / sum(s)
}
