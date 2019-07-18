## This will probably get generalised out later but should work with
## most of the combination plots for now I think.
plotly_combine_series <- function(a, b, names) {
  n <- c(length(a), length(b))
  ret <- c(a, b)

  dash <- rep(c("solid", "dash"), n)
  name <- rep(names$long[1:2], n)

  for (i in seq_along(ret)) {
    x <- ret[[i]]

    x$name <- sprintf("%s (%s)", x$name, name[[i]])
    if ("line" %in% names(x)) {
      x$line$dash <- dash[[i]]
    }

    ret[[i]] <- x
  }

  ret
}