# derivePoints -------------------------------------------------------------

test_that("can get point data from SpatialPointsDataFrame", {
  skip_if_not_installed("sp")
  data("meuse", package = "sp", envir = environment())
  sp::coordinates(meuse) <- ~x + y

  points <- derivePoints(meuse)
  expect_named(points, c("lng", "lat"))
  expect_equal(nrow(points), 155)
})

test_that("derivePolygons works with sf classes", {
  skip_if_not_installed("sp")

  data("meuse", package = "sp", envir = environment())
  sp::coordinates(meuse) <- ~x + y
  meuse <- sf::st_as_sf(meuse)

  points <- derivePoints(meuse)
  expect_named(points, c("lng", "lat"))
  expect_equal(nrow(points), 155)
})

# derivePolygons -----------------------------------------------------------

verifyPolygonData <- function(x) {
  expect_true(!is.null(attr(x, "bbox", exact = TRUE)))
  expect_type(x, "list")
  lapply(x, function(multipolygon) {
    expect_type(multipolygon, "list")
    lapply(multipolygon, function(polygon) {
      expect_type(polygon, "list")
      lapply(polygon, function(ring) {
        expect_s3_class(ring, "data.frame")
      })
    })
  })
  x
}

test_that("derivePolygons normalizes polygon data across sp polygon classes", {
  skip_if_not_installed("sp")
  rlang::local_options("rlib_warning_verbosity" = "verbose")
  data("meuse.riv", package = "sp", envir = environment())
  df <- data.frame(x = 1, row.names = "river")

  poly <- sp::Polygon(meuse.riv)
  expect_warning(out <- derivePolygons(poly), "transform")
  verifyPolygonData(out)
  expect_equal(out[[1]][[1]][[1]]$lng, meuse.riv[, 1])
  expect_equal(out[[1]][[1]][[1]]$lat, meuse.riv[, 2])
  # row/col names are different but values are the same
  expect_equal(attr(out, "bbox"), sp::bbox(meuse.riv), ignore_attr = TRUE)

  polys <- sp::Polygons(list(poly), "river")
  expect_warning(res <- derivePolygons(polys), "transform")
  expect_equal(res, out)

  spolys <- sp::SpatialPolygons(list(polys))
  expect_equal(derivePolygons(spolys), out)

  spolysdf <- sp::SpatialPolygonsDataFrame(spolys, df)
  expect_equal(derivePolygons(spolysdf), out)
})

test_that("derivePolygons normalizes polygon data across sp line classes", {
  skip_if_not_installed("sp")
  rlang::local_options("rlib_warning_verbosity" = "verbose")
  data("meuse.riv", package = "sp", envir = environment())
  df <- data.frame(x = 1, row.names = "river")

  line <- sp::Line(meuse.riv)
  expect_warning(out <- derivePolygons(line), "transform")
  verifyPolygonData(out)
  expect_equal(out[[1]][[1]][[1]]$lng, meuse.riv[, 1])
  expect_equal(out[[1]][[1]][[1]]$lat, meuse.riv[, 2])
  # row/col names are different but values are the same
  expect_equal(attr(out, "bbox"), sp::bbox(meuse.riv), ignore_attr = TRUE)

  lines <- sp::Lines(list(line), "river")
  expect_warning(res <- derivePolygons(lines), "transform")
  expect_equal(res, out)

  slines <- sp::SpatialLines(list(lines))
  expect_equal(derivePolygons(slines), out)

  slinesdf <- sp::SpatialLinesDataFrame(slines, df)
  expect_equal(derivePolygons(slinesdf), out)

  expect_equal(derivePolygons(sf::st_as_sfc(slines)[[1]]), out)
  expect_equal(derivePolygons(sf::st_as_sfc(slines)), out)
})

test_that("derivePolygons works with sf classes", {
  nc <- sf::st_read(system.file("shape/nc.shp", package = "sf"), quiet = TRUE)

  expect_warning(
    polys <- derivePolygons(nc),
    "inconsistent datum"
  )

  expect_length(polys, nrow(nc))
  verifyPolygonData(polys)

  expect_warning(verifyPolygonData(derivePolygons(sf::st_geometry(nc))))
  verifyPolygonData(derivePolygons(sf::st_geometry(nc)[[1]]))
  verifyPolygonData(derivePolygons(sf::st_polygon(sf::st_geometry(nc)[[1]][[1]])))
})

# guessLatLongCols --------------------------------------------------------
ll_names <- function(lng, lat) list(lng = lng, lat = lat)

test_that("guesses lat/long names", {

  # Abbreviations
  expect_equal(guessLatLongCols(c("lat", "lng")), ll_names("lng", "lat"))
  expect_equal(guessLatLongCols(c("lat", "lon")), ll_names("lon", "lat"))
  expect_equal(guessLatLongCols(c("lat", "long")), ll_names("long", "lat"))

  # Ignores case
  expect_equal(guessLatLongCols(c("Lat", "Lng")), ll_names("Lng", "Lat"))

  # Understands full names
  expect_equal(
    guessLatLongCols(c("latitude", "longitude")),
    ll_names("longitude", "latitude")
  )
})

test_that("gives message if additional columns", {
  expect_message(
    guessLatLongCols(c("lat", "lon", "foo")),
    "Assuming \"lon\" and \"lat\""
  )
})

test_that("fails if not lat/long columns present", {
  expect_error(
    guessLatLongCols(c("Lat", "foo")),
    "Couldn't infer longitude/latitude columns"
  )

  expect_error(
    guessLatLongCols(c("Lat", "lat", "Long")),
    "Couldn't infer longitude/latitude columns"
  )
})
