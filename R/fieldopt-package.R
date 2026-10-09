#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang .data
#' @importFrom ggplot2 autoplot
## usethis namespace: end
NULL

#' @export
ggplot2::autoplot

#' @export
generics::tidy

#' @export
generics::glance

#' Version of the Rust engine
#'
#' @return The version string of the `fieldopt-core` crate compiled into the
#'   package.
#' @export
#' @examples
#' core_version()
core_version <- function() core_version_rs()
