# io.R — file I/O helpers for NSSK.R
#
# Sourced by NSSK.R during workspace setup (section 1.1.1).

# CSV dialect for this project's files. Overridable per-call (see write_df_to_csv),
# but every write to a given file must use the same dialect as the write that created it.
CSV_SEP_COMMA      <- ","      # field separator
CSV_DEC_PERIOD     <- "."      # decimal mark
CSV_QMETHOD_DOUBLE <- "double" # quote embedded quotes as "" (RFC 4180), not write.table()'s default backslash-escape
CSV_ROW_NAMES_FALSE <- FALSE   # no row-name column

# Binary file() modes (see ?connections). Binary, not text, so no platform-dependent
# LF -> CRLF translation on write.
FILE_MODE_WRITE_BINARY  <- "wb" # truncate/create for writing
FILE_MODE_APPEND_BINARY <- "ab" # append, creating if absent

# Writes x to path as CSV with LF line endings on every platform (write.table()'s default
# text-mode connection converts LF -> CRLF on Windows; opening the connection ourselves in
# binary mode avoids that -- see ?connections).
#
# append   - TRUE appends data rows with no header (for batched writes); FALSE (default)
#            writes a fresh file with a header row
# sep      - default CSV_SEP_COMMA. write.table()'s own default is " ", not ",". An append
#            call that omits sep writes that batch's rows with a different separator than
#            the rest of the file -- read.csv() misparses them silently, no error
# row.names - default CSV_ROW_NAMES_FALSE. write.table()'s own default is TRUE, which
#            restarts row names at 1 in each appended batch; read.csv() then errors with
#            "duplicate 'row.names' are not allowed" on read-back
write_df_to_csv <- function(x, path, append = FALSE,
                             sep = CSV_SEP_COMMA,
                             row.names = CSV_ROW_NAMES_FALSE) {
  file_mode <- if (append) FILE_MODE_APPEND_BINARY else FILE_MODE_WRITE_BINARY
  con <- file(path, open = file_mode)
  on.exit(close(con), add = TRUE) # ensure the file handle is closed both on return and if the call to write.table() encounters errors

  # write.csv()'s own header-column rule: blank header cell (NA) over the row-name
  # column unless row.names is FALSE. Never a header at all when appending.
  col.names <- if (append) FALSE else if (is.logical(row.names) && !row.names) TRUE else NA

  write.table(x, con,
              sep = sep,
              dec = CSV_DEC_PERIOD,
              qmethod = CSV_QMETHOD_DOUBLE,
              row.names = row.names,
              col.names = col.names)
}
