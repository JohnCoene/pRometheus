######################################################################
#' Memory adapter
#'
#' Internal memory structure for storing Prometheus metrics
#' @importFrom R6 R6Class
#' @export
PrometheusMemoryAdapter <- R6Class(
  "PrometheusMemoryAdapter",
  lock_objects = FALSE,
  public = list(
    #' Initializing PrometheusMemoryAdapter
    #'
    #' @return instance of PrometheusMemoryAdapter
    initialize = function() {},

    #' Gather up all known metric samples
    #'
    #' @return vector of metric samples
    collect = function() {
      collected_gauges <- private$internalCollect(private$gauges)
      collected_counters <- private$internalCollect(private$counters)

      metrics <- c(collected_gauges, collected_counters)
      return(metrics)
    },

    #' Upsert a given gauge in memory
    #'
    #' @param input_list list of values needed to update a gauge
    #' @return PrometheusGauge being updated
    updateGauge = function(input_list) {
      meta_key <- private$getMetaKey(input_list)
      value_key <- private$getValueKey(input_list)

      if (!(meta_key %in% names(private$gauges))) {
        new_element <-
          list('meta' = private$buildMetaData(input_list),
               'samples' = list())

        private$gauges[[meta_key]] <- new_element
      }

      if (!(value_key %in% names(private$gauges[[meta_key]][['samples']]))) {
        private$gauges[[meta_key]][['samples']][[value_key]] <- 0
      }

      private$gauges[[meta_key]][['samples']][[value_key]] = private$gauges[[meta_key]][['samples']][[value_key]] + input_list$value
    },

    #' Upsert a given counter in memory
    #'
    #' @param input_list list of values needed to update a counter
    #' @return PrometheusCounter being updated
    updateCounter = function(input_list) {
      meta_key <- private$getMetaKey(input_list)
      value_key <- private$getValueKey(input_list)

      if (!(meta_key %in% names(private$counters))) {
        new_element <-
          list('meta' = private$buildMetaData(input_list),
               'samples' = list())

        private$counters[[meta_key]] <- new_element
      }

      if (!(value_key %in% names(private$counters[[meta_key]][['samples']]))) {
        private$counters[[meta_key]][['samples']][[value_key]] <- 0
      }

      private$counters[[meta_key]][['samples']][[value_key]] = private$counters[[meta_key]][['samples']][[value_key]] + input_list$value
    }
  ),
  private = list(
    gauges = list(),
    counters = list(),
    getMetaKey = function(input_list) {
      return (paste(input_list$type, input_list$name, 'meta', sep = ":"))
    },
    getValueKey = function(input_list) {
      return (paste(
        input_list$type,
        input_list$name,
        jsonlite::base64_enc(serialize(input_list$label_values, NULL)),
        'value',
        sep = ":"
      ))
    },
    buildMetaData = function(input_list) {
      return (input_list[c('name', 'help', 'type', 'label_names')])
    },
    internalCollect = function(input_list) {
      results = list()
      for (metric in input_list) {
        family_samples <- MetricFamilySample$new(
          name = metric[['meta']][['name']],
          type = metric[['meta']][['type']],
          help = metric[['meta']][['help']],
          label_names = metric[['meta']][['label_names']]
        )

        samples = list()

        for (sample_key in names(metric[['samples']])) {
          sample_value <- metric[['samples']][[sample_key]]

          parts <- strsplit(sample_key, ":")

          new_sample <- PrometheusSample$new(
            name = metric[['meta']][['name']],
            value = sample_value,
            label_names = metric[['meta']][['label_names']],
            label_values = unserialize(jsonlite::base64_dec(parts[[1]][3]))
          )

          samples <- c(samples, new_sample)
        }

        family_samples$setSamples(samples)
        meta_key_list <- list(name = metric[['meta']][['name']],
                              type = metric[['meta']][['type']])

        family_key = private$getMetaKey(meta_key_list)
        results[[family_key]] <- family_samples
      }

      return(results)
    }
  )
)
