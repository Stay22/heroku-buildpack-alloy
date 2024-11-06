# Grafana Alloy Heroku Buildpack

This Heroku buildpack installs the Grafana Alloy Agent in your Heroku dyno to collect logs, metrics, traces and profiling telemetry data. This buildpack is inspired by the [Datadog's agent buildpack](https://github.com/DataDog/heroku-buildpack-datadog).

## Usage

All that is required to use this buildpack is to add an Alloy configuration file named `config.alloy` in the root folder of your Heroku app repository. When your app starts, it will run the Alloy agent with this `config.alloy` configuration.
After you have added the Alloy configuration file, you can add the buildpack to your Heroku application:

```bash
heroku buildpacks:add --index 1 https://github.com/Stay22/heroku-buildpack-alloy.git -a <app name>
```

## Heroku dyno metadata

In order to benefit from resource detection and get additional Heroku metadata associated with your telemetry data, the [Heroku Dyno Metadata](https://devcenter.heroku.com/articles/dyno-metadata) feature should be enabled.

```bash
heroku labs:enable runtime-dyno-metadata -a <app name>
heroku labs:enable runtime-dyno-build-metadata -a <app name>
```

## Example

Below is an example Alloy configuration file which can be used to get started to send logs, traces and metrics to Grafana Cloud.

The below environment variables will be required for this example configuration.

| Environment variable name | Description                                                                                               |
| ------------------------- | --------------------------------------------------------------------------------------------------------- |
| GRAFANA_OTLP_ENDPOINT     | Grafana OTLP endpoint. Example: https://otlp-gateway-prod-ca-east-0.grafana.net/otlp                      |
| GRAFANA_OTLP_USERNAME     | Grafana OTLP username                                                                                     |
| GRAFANA_PROM_ENDPOINT     | Grafana Prometheus endpoint. Example: https://prometheus-prod-32-prod-ca-east-0.grafana.net/api/prom/push |
| GRAFANA_PROM_USERNAME     | Grafana Prometheus username                                                                               |
| GRAFANA_LOKI_ENDPOINT     | Grafana Loki endpoint. Example: https://logs-prod-018.grafana.net/loki/api/v1/push                        |
| GRAFANA_LOKI_USERNAME     | Grafana Loki username                                                                                     |
| GRAFANA_API_TOKEN         | Grafana Access Policy token with the following scopes: `logs:write`, `metrics:write`, `traces:write`      |
| HEROKU_APP_NAME           | The heroku app name, unless the [Heroku dyno metadata feature](#heroku-dyno-metadata) is enabled.         |

This is only an example configuration for Alloy. See the official [Grafana Allow reference documentation](https://grafana.com/docs/alloy/latest/reference/) for more info.

```
otelcol.receiver.otlp "default" {
	// configures the default grpc endpoint "0.0.0.0:4317"
	grpc { }
	// configures the default http/protobuf endpoint "0.0.0.0:4318"
	http { }

	output {
		metrics = [otelcol.processor.resourcedetection.default.input]
		logs    = [otelcol.processor.resourcedetection.default.input]
		traces  = [otelcol.processor.resourcedetection.default.input]
	}
}

otelcol.processor.resourcedetection "default" {
	detectors = ["env", "system", "heroku"]

	system {
		hostname_sources = ["os"]
	}

	output {
		metrics = [otelcol.processor.transform.drop_unneeded_resource_attributes.input]
		logs    = [otelcol.processor.transform.drop_unneeded_resource_attributes.input]
		traces  = [otelcol.processor.transform.drop_unneeded_resource_attributes.input]
	}
}

otelcol.processor.transform "drop_unneeded_resource_attributes" {
	// https://grafana.com/docs/alloy/latest/reference/components/otelcol.processor.transform/
	error_mode = "ignore"

	trace_statements {
		context    = "resource"
		statements = [
			"delete_key(attributes, \"k8s.pod.start_time\")",
			"delete_key(attributes, \"os.description\")",
			"delete_key(attributes, \"os.type\")",
			"delete_key(attributes, \"process.command_args\")",
			"delete_key(attributes, \"process.executable.path\")",
			"delete_key(attributes, \"process.pid\")",
			"delete_key(attributes, \"process.runtime.description\")",
			"delete_key(attributes, \"process.runtime.name\")",
			"delete_key(attributes, \"process.runtime.version\")",
		]
	}

	metric_statements {
		context    = "resource"
		statements = [
			"delete_key(attributes, \"k8s.pod.start_time\")",
			"delete_key(attributes, \"os.description\")",
			"delete_key(attributes, \"os.type\")",
			"delete_key(attributes, \"process.command_args\")",
			"delete_key(attributes, \"process.executable.path\")",
			"delete_key(attributes, \"process.pid\")",
			"delete_key(attributes, \"process.runtime.description\")",
			"delete_key(attributes, \"process.runtime.name\")",
			"delete_key(attributes, \"process.runtime.version\")",
		]
	}

	log_statements {
		context    = "resource"
		statements = [
			"delete_key(attributes, \"k8s.pod.start_time\")",
			"delete_key(attributes, \"os.description\")",
			"delete_key(attributes, \"os.type\")",
			"delete_key(attributes, \"process.command_args\")",
			"delete_key(attributes, \"process.executable.path\")",
			"delete_key(attributes, \"process.pid\")",
			"delete_key(attributes, \"process.runtime.description\")",
			"delete_key(attributes, \"process.runtime.name\")",
			"delete_key(attributes, \"process.runtime.version\")",
		]
	}

	output {
		metrics = [otelcol.processor.transform.add_resource_attributes_as_metric_attributes.input]
		logs    = [otelcol.processor.batch.default.input]
		traces  = [
			otelcol.processor.batch.default.input,
			otelcol.connector.host_info.default.input,
		]
	}
}

otelcol.connector.host_info "default" {
	host_identifiers = ["host.name"]

	output {
		metrics = [otelcol.processor.batch.default.input]
	}
}

otelcol.processor.transform "add_resource_attributes_as_metric_attributes" {
	error_mode = "ignore"

	metric_statements {
		context    = "datapoint"
		statements = [
			"set(attributes[\"deployment.environment\"], resource.attributes[\"deployment.environment\"])",
			"set(attributes[\"service.version\"], resource.attributes[\"service.version\"])",
		]
	}

	output {
		metrics = [otelcol.processor.batch.default.input]
	}
}

otelcol.processor.batch "default" {
	output {
		metrics = [otelcol.exporter.otlphttp.grafana_cloud.input]
		logs    = [otelcol.exporter.otlphttp.grafana_cloud.input]
		traces  = [otelcol.exporter.otlphttp.grafana_cloud.input]
	}
}

// Metamonitoring for Alloy metrics and logs
prometheus.exporter.self "metamonitoring" { }

discovery.relabel "metamonitoring" {
	targets = prometheus.exporter.self.metamonitoring.targets

	rule {
		replacement  = string.format("%s.%s", sys.env("HEROKU_APP_NAME"), constants.hostname)
		target_label = "instance"
	}

	rule {
		target_label = "job"
		replacement  = "integrations/alloy"
	}
}

prometheus.scrape "self" {
	targets    = discovery.relabel.metamonitoring.output
	forward_to = [prometheus.remote_write.grafana_cloud.receiver]
	job_name   = "integrations/alloy"
}

logging {
	write_to = [loki.process.logs_integrations_integrations_alloy_health.receiver]
}

loki.process "logs_integrations_integrations_alloy_health" {
	forward_to = [loki.relabel.logs_integrations_integrations_alloy_health.receiver]

	stage.regex {
		expression = "(level=(?P<log_level>[\\s]*debug|warn|info|error))"
	}

	stage.labels {
		values = {
			level = "log_level",
		}
	}
}

loki.relabel "logs_integrations_integrations_alloy_health" {
	forward_to = [loki.write.grafana_cloud.receiver]

	rule {
		replacement  = string.format("%s.%s", sys.env("HEROKU_APP_NAME"), constants.hostname)
		target_label = "instance"
	}

	rule {
		target_label = "job"
		replacement  = "integrations/alloy"
	}
}

// Exporters
loki.write "grafana_cloud" {
	endpoint {
		url = sys.env("GRAFANA_LOKI_ENDPOINT")

		basic_auth {
			username = sys.env("GRAFANA_LOKI_USERNAME")
			password = sys.env("GRAFANA_API_TOKEN")
		}
	}
}

otelcol.exporter.otlphttp "grafana_cloud" {
	client {
		endpoint = sys.env("GRAFANA_OTLP_ENDPOINT")
		auth     = otelcol.auth.basic.grafana_cloud.handler
	}
}

otelcol.auth.basic "grafana_cloud" {
	username = sys.env("GRAFANA_OTLP_USERNAME")
	password = sys.env("GRAFANA_API_TOKEN")
}

prometheus.remote_write "grafana_cloud" {
	endpoint {
		url = sys.env("GRAFANA_PROM_ENDPOINT")

		basic_auth {
			username = sys.env("GRAFANA_PROM_USERNAME")
			password = sys.env("GRAFANA_API_TOKEN")
		}
	}
}
```

## Troubleshooting

If the Alloy agent cannot properly start (e.g. because of a misconfiguration in Alloy), the Heroku app will not be prevented from starting, but you will not be able to process telemetry data. If you don't see any telemetry data received by your Grafana or other Open Telemetry backend, you can see the Alloy agent logs in Heroku along with your app. The agent will always attempt to start before your application, so if it fails to start you should be able to see more information there.

```bash
heroku logs logs -a <app name>
```
