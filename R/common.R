module_status <- function(class, title, body) {
  list(ui = simple_panel(class, title, body),
       class = class,
       ok = class == "success")
}


show_module_status_if_not_ok <- function(x) {
  if (!isTRUE(x$ok)) {
    x$ui
  }
}


show_module_status_if_ok <- function(x) {
  if (isTRUE(x$ok)) {
    x$ui
  }
}


text_module_status <- function(x) {
  paste0("text-", x$class %||% "danger")
}


get_inputs <- function(input, ids, names = ids) {
  set_names(lapply(ids, function(x) input[[x]]), names)
}


set_inputs <- function(session, ids, values, fn = shiny::updateNumericInput) {
  for (i in seq_along(ids)) {
    fn(session, ids[[i]], value = values[[i]])
  }
}


restore_inputs <- function(session, data, fn = NULL) {
  if (is.null(fn)) {
    if (all(vlapply(data, is.logical))) {
      fn <- shiny::updateCheckboxInput
    } else {
      fn <- shiny::updateNumericInput
    }
  }
  set_inputs(session, names(data), unname(data), fn)
}


odin_colours <- function(model, data, link) {
  col_model <- odin_colours_model(model)
  col_data <- odin_colours_data(data)

  if (length(link) > 0L) {
    link <- list_to_character(link, TRUE)
    col_model[link] <- col_data[names(link)]
  }

  list(model = col_model, data = col_data)
}


odin_colours_data <- function(data) {
  pal <- c("#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "#FF7F00", "#FFFF33",
           "#A65628", "#F781BF")
  set_names(pal[seq_along(data)], data)
}


odin_colours_model <- function(model) {
  pal <- grDevices::colorRampPalette(
    c("#2e5cb8", "#39ac73", "#cccc00", "#ff884d", "#cc0044"))
  set_names(pal(length(model)), model)
}


odin_y2 <- function(y2_model, name_data, link) {
  y2_model <- vlapply(y2_model, isTRUE)
  y2_data <- set_names(rep(FALSE, length(name_data)), name_data)
  y2_data[names(link)] <- y2_model[list_to_character(link)]
  list(model = y2_model, data = y2_data)
}


common_model_data_configuration <- function(model, data, link,
                                            run_options = NULL) {
  if (!isTRUE(model$success)) {
    return(NULL)
  }
  if (!isTRUE(data$configured) && !isTRUE(run_options$control_end_time)) {
    return(NULL)
  }

  ## Augment parameters with standard ids for working with shiny ui
  ## elements
  pars <- model$info$pars
  pars$value <- vnapply(pars$default_value, function(x) x %||% NA_real_)
  pars$id_value <- sprintf("par_value_%s", pars$name)

  ## ...and same for the variables, but we'll do this as a "graph
  ## option" because the place that this will turn up is the graphing
  ## options seection.
  vars <- model$info$vars
  vars$id_graph_option <- sprintf("var_graph_option_%s", vars$name)

  cols <- odin_colours(vars$name, data$name_vars, link$map)

  download_names <- download_names(
    display = c("Modelled", "Combined", "Parameters"),
    filename = c("modelled", "combined", "parameters"),
    data = c("smooth", "combined", "user"))

  list(data = data, model = model, link = link,
       pars = pars, vars = vars, cols = cols,
       download_names = download_names)
}


## The only thing that's actually hard to save
common_model_data_configuration_save <- function(configuration) {
  if (is.null(configuration)) {
    return(NULL)
  }
  configuration$model <- editor_save(configuration$model)
  configuration
}


common_model_data_configuration_restore <- function(configuration) {
  if (is.null(configuration)) {
    return(NULL)
  }
  configuration$model <- editor_restore(configuration$model)
  configuration
}


add_status <- function(x, status) {
  c(x, list(status = status))
}


## Standard data structure for a data set that knows what is going on
## with time.
odin_data_source <- function(data, filename, name_time) {
  vars <- names(data)
  if (is_missing(name_time) || !(name_time %in% vars)) {
    name_time <- NULL
  }
  configured <- !is.null(data) && !is.null(name_time)
  result <- list(data = data, filename = filename, configured = configured)

  if (configured) {
    result$name_time <- name_time
    result$name_vars <- setdiff(vars, name_time)
    result$cols <- odin_colours_data(result$name_vars)
  }

  result
}


## result here must be the output of odin::odin_build, which includes:
##
## success, elapsed, output, model, ir & error
odin_model <- function(result, code, name = NULL, name_short = NULL) {
  if (is.null(result)) {
    result <- list(success = FALSE)
  }
  if (result$success) {
    result$info <- model_info(result$model)
  }
  if (!is.null(result$elapsed)) {
    result$elapsed <- result$elapsed[["elapsed"]]
  }
  result$name <- name %||% "model"
  result$name_short <- name_short %||% clean_name(result$name)
  result$code <- code
  result$is_current <- TRUE
  result
}


common_odin_validate <- function(code) {
  res <- odin::odin_validate(strip_linefeed(code), "text")
  if (!is.null(res$error)) {
    res$error <- res$error$message
  }
  res$code <- code
  res$messages <- vcapply(res$messages, function(x) x$message)
  res
}


common_odin_compile <- function(validation, name = NULL, name_short = NULL) {
  if (!validation$success) {
    return(NULL)
  }
  result <- odin::odin_build(validation$result)
  odin_model(result, validation$code, name = name, name_short = name_short)
}


common_odin_compile_from_code <- function(code) {
  common_odin_compile(common_odin_validate(code))
}


models_compatible <- function(cfg1, cfg2) {
  identical(cfg1$pars$name, cfg2$pars$name) &&
    identical(cfg1$vars$name, cfg2$vars$name)
}


import_from_fit <- function(user = NULL) {
  if (!shiny::is.reactive(user)) {
    user <- shiny::reactive(user)
  }
  list(user = user,
       title = "Import from fit",
       icon = shiny::icon("calculator"))
}


submodules <- function(...) {
  modules <- list(...)

  has_reset <- vlapply(modules, has_function, "reset")
  has_state <- vlapply(modules, has_function, "get_state")

  list(
    reset = function() {
      for (m in modules[has_reset]) {
        m$reset()
      }
    },
    get_state = function() {
      tryCatch(
        lapply(modules[has_state], function(m) m$get_state()),
        error = function(e) {
          message(e$message)
          browser()
        })
    },
    set_state = function(state) {
      nms <- names_if(has_state)
      Map2(function(n, m, s) {
        m$set_state(s)
      }, nms, modules[nms], state[nms])
    })
}


odin_ui_version_information <- function() {
  shiny::tagList(
    shiny::h2("Version information"),
    shiny::p(sprintf("odin.ui version %s, odin version %s",
                     package_version("odin.ui"), package_version("odin"))))
}
