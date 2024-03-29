# wrappers for using iotools locally; loads input, writes output,

input.file <- function(file_name, formatter = mstrsplit, ...) {
  if (is.character(file_name)) {
    input = file(file_name, "rb")
    on.exit(close(input))
  } else {
    stop("'file_name' must be a character string to a file path.")
  }

  n = file.info(file_name)$size
  formatter(readBin(input, what="raw", n=n), ...)
}

output.file <- function(x, file, formatter.output = NULL) {
  if (is.character(ret <- file)) {
    output = file(file, "wb")
    on.exit(close(output))
  } else if (inherits(file, "connection")) {
    output = file
  } else {
    stop("'file' must be a connection or a character string to a file path.")
  }
  if (is.null(formatter.output)) formatter.output <- as.output

  writeLines(formatter.output(x), output)
  invisible(ret)
}


readAsRaw <- function (con, n, nmax, fileEncoding = "")
{
  if (is.character(con)) {
      con = path.expand(con)
      if (missing(n)) { ## one-shot file read
          n = file.info(con)$size
          if (!any(is.na(n)))
              return(readBin(con, raw(), n))
      }
      con = if(nzchar(fileEncoding))
            file(con, "rb", encoding = fileEncoding) else file(con, "rb")
      on.exit(close(con))
  }
  if (!isOpen(con, "rb")) {
      open(con, "rb")
      on.exit(close(con))
  }
  if (missing(n) || any(is.na(n))) n = 1048576L
  if (missing(nmax)) nmax = Inf
  mode = summary.connection(con)$mode

  if (mode == "r") {
    ans = raw()
    m = 0
    while(TRUE) {
      this = charToRaw(readChar(con, nchars = min(n, nmax - m), useBytes = TRUE))
      ans = c(ans, this)
      m = m + length(this)
      if ((length(this) < n) || (nmax - m <= 0) ) break
      n = n * 2
    }
  } else if (mode == "rb") {
    ans = raw()
    m = 0
    while(TRUE) {
      this = readBin(con, raw(), min(n, nmax - m))
      ans = c(ans, this)
      m = m + length(this)
      if ((length(this) < n) || (nmax - m <= 0) ) break
      n = n * 2
    }
  } else {
    stop("Connection con must be in read mode.")
  }
  return(ans)
}

read.csv.raw = function(file, header=TRUE, sep=",", skip=0L, fileEncoding="",
                        colClasses, nrows = -1L, nsep = NA, strict=TRUE,
                        nrowsClasses = 25L, quote="'\"") {

  # Read in data as a raw vector:
  if (missing(file))
    stop('argument "file" is missing, with no default')

  if (!missing(colClasses) && is.list(colClasses))
    colClasses = sapply(colClasses, function(v) class(v)[1])

  r = if (is.raw(file)) file else readAsRaw(file, fileEncoding = fileEncoding)
  if (!missing(colClasses) && !all(is.na(colClasses)))
    colClasses[colClasses %in% c("real", "double")] = "numeric"

  # Run a small subset of the data through read.table:
  if (missing(colClasses)) {
    subset = mstrsplit(r, sep=sep, nsep=nsep, nrows=nrowsClasses, skip=skip+header)

    colClasses = rep(NA_character_, ncol(subset))
    for (i in 1:ncol(subset))
      colClasses[i] = class(type.convert(subset[,i],as.is=TRUE))

    # If all NA's, R makes it logical; better to be character
    index = which(apply(!is.na(subset), 2, sum) == 0)
    if (length(index))
      colClasses[index] = "character"

    if (!is.na(nsep))
      colClasses = colClasses[-1]
  }

  # Process header
  if (header & is.null(names(colClasses))) {
    col_names = mstrsplit(r, sep=sep, nsep=nsep, nrows=1)
    if ((length(col_names) - 1 == length(colClasses)) && !is.na(nsep))
      col_names = col_names[-1]

    names(colClasses) = col_names
  }

  dstrsplit(r, colClasses, sep = sep, nsep = nsep, strict = strict,
            skip = skip+header, nrows = nrows, quote = quote)
}

read.delim.raw = function(file, header=TRUE, sep="\t", ...) {
  read.csv.raw(file=file, header=header, sep=sep, ...)
}

write.csv.raw = function(x, file = "", append = FALSE, sep = ",", nsep="\t",
                          col.names = !is.null(colnames(x)), fileEncoding = "") {
  if (is.character(file)) {
    file <- if (nzchar(fileEncoding))
            file(file, ifelse(append, "ab", "wb"), encoding = fileEncoding)
        else file(file, ifelse(append, "ab", "wb"))
    on.exit(close(file))
  } else if (!isOpen(file, "w")) {
    open(file, "wb")
    on.exit(close(file))
  }

  if (col.names) {
    cr = rawToChar(as.output(matrix(colnames(x),nrow=1),sep = sep))
    writeBin(cr, con=file)
  }

  r = as.output(x, sep = sep, nsep=nsep)
  writeBin(r, con=file)
}

write.table.raw = function(x, file = "", sep = " ", ...) {
  write.csv.raw(x, file=file, sep=sep, ...)
}

chunk.map = function(input, output = NULL, formatter = .default.formatter,
                      FUN, key.sep = NULL, max.line = 65536L,
                      max.size = 33554432L, output.sep = ",", output.nsep = "\t",
                      output.keys = FALSE, skip = 0L, ...) {

  if (is.character(input)) {
    input = file(input, "rb")
    on.exit(close(input))
  }
  if (is.character(output)) {
    output = file(output, "wb")
    on.exit(close(output))
  }

  res <- list()
  if (skip > 0L) readLines(input, n=skip)
  cr = chunk.reader(input, max.line = max.line, sep = key.sep)

  while ( length(r <- read.chunk(cr, max.size = max.size)) ) {
    val = FUN(formatter(r), ...)

    if (!is.null(output)) {
      rout = as.output(val, sep = output.sep, nsep = output.nsep, keys = output.keys)
      writeBin(rout, output)
    } else {
      res <- append(res, list(val))
    }
  }

  if (is.null(output)) return(res)
}






