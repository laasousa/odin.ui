mod_control_run_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::uiOutput(ns("ui"))
}


## This will need some work for a *pair* of models?
mod_control_run_server <- function(input, output, session, render, options,
                                   warn_show = TRUE) {
  rv <- shiny::reactiveValues()
  options <- control_run_options_validate(options)

  shiny::observe({
    rv$configuration <- control_run_configuration(render(), options)
  })

  output$ui <- shiny::renderUI({
    control_run_ui(rv$configuration, session$ns)
  })

  shiny::observe({
    rv$values <- control_run_result(
      options, get_inputs(input, rv$configuration$inputs))
  })

  output$status <- shiny::renderUI({
    control_run_status(rv$values, warn_show)
  })

  shiny::outputOptions(output, "ui", suspendWhenHidden = FALSE)

  get_state <- function() {
    if (is.null(rv$configuration)) {
      return(NULL)
    }
    get_inputs(input, rv$configuration$inputs)
  }

  set_state <- function(state) {
    if (!is.null(state)) {
      rv$configuration <- control_run_configuration(TRUE, options)
      restore_inputs(session, state)
    }
  }

  reset <- function() {
    output$ui <- shiny::renderUI(
        control_run_ui(rv$configuration, session$ns))
  }

  list(
    result = shiny::reactive(rv$values),
    reset = reset,
    get_state = get_state,
    set_state = set_state)
}


control_run_configuration <- function(render, options) {
  if (!isTRUE(render)) {
    return(NULL)
  }

  inputs <- drop_null(list(
    control_end_time = if (options$options$control_end_time) "end",
    control_nout = "nout",
    use_relicates = if (options$options$replicates) "replicates"))

  list(options = options, inputs = inputs)
}


control_run_ui <- function(configuration, ns) {
  if (is.null(configuration)) {
    return(NULL)
  }

  options <- configuration$options

  end <- replicates <- NULL
  if (options$options$control_end_time) {
    value_end <- options$control$default_end_time
    end <- simple_numeric_input("End time", ns("end"), value_end)
  }
  nout <- simple_numeric_input("Number of output points", ns("nout"),
                               options$control$default_nout)
  if (options$options$replicates) {
    value_replicates <- options$control$default_replicates
    replicates <- simple_numeric_input(
      "Replicates", ns("replicates"), value_replicates)
  }

  status <- shiny::uiOutput(ns("status"))

  tags <- drop_null(list(end, nout, replicates, status))
  odin_control_section("Run options", tags, ns = ns)
}


control_run_status <- function(values, warn_show) {
  if (is_missing(values$values$replicates)) {
    return(NULL)
  }
  if (isTRUE(values$values$no_run)) {
    simple_panel("danger", "Too many replicates requested", NULL)
  } else if (warn_show && isTRUE(values$values$no_show)) {
    simple_panel("warning", "Individual traces will be hidden", NULL)
  }
}


control_run_result <- function(options, values) {
  if (options$options$replicates) {
    replicates <- values$replicates
    if (!is_missing(replicates)) {
      values$no_run <- replicates > options$control$max_replicates_run
      values$no_show <- replicates > options$control$max_replicates_show
    }
  }
  list(options = options$options,
       control = options$control,
       values = values)
}


control_run_options <- function(control_end_time = FALSE,
                                replicates = FALSE,
                                scale_time = FALSE,
                                default_end_time = NA,
                                default_nout = 500,
                                default_replicates = NA,
                                max_replicates_show = 20,
                                max_replicates_run = 1000) {
  ret <- list(options = list(control_end_time = control_end_time,
                             replicates = replicates,
                             scale_time = scale_time),
              control = list(default_end_time = default_end_time,
                             default_nout = default_nout,
                             default_replicates = default_replicates,
                             max_replicates_show = max_replicates_show,
                             max_replicates_run = max_replicates_run))
  class(ret) <- "control_run_options"
  ret
}


control_run_options_validate <- function(options) {
  if (inherits(options, "control_run_options")) {
    return(options)
  }
  control_run_options(
    control_end_time = options$control_end_time %||% FALSE,
    replicates = options$replicates %||% FALSE,
    scale_time = options$scale_time %||% FALSE,
    default_end_time = options$default_end_time %||% NA,
    default_replicates = options$default_replicates %||% NA,
    max_replicates_show = options$max_replicates_show %||% 20,
    max_replicates_run = options$max_replicates_run %||% 1000)
}


control_run_default <- function() {
  control_run_result(control_run_options(), NULL)
}
