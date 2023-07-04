require "./spec/config"
require "./lib/prometheus_parser"

describe PrometheusParser do
  it "should parse simple metric" do
    raw = <<~METRICS
      response_packet_get_children_cache_hits 0.0
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.size).must_equal 1
    _(res.first[:key]).must_equal "response_packet_get_children_cache_hits"
    _(res.first[:value]).must_equal 0.0
    _(res.first[:attrs]).must_be_empty
  end

  it "should parse many metrics" do
    raw = <<~METRICS
      kafka_cluster_partition_underminisr 0
      kafka_network_requestmetrics_totaltimems 179494
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.size).must_equal 2
    _(res.first[:key]).must_equal "kafka_cluster_partition_underminisr"
    _(res.first[:value]).must_equal 0.0
    _(res.first[:attrs]).must_be_empty
    _(res[1][:key]).must_equal "kafka_network_requestmetrics_totaltimems"
    _(res[1][:value]).must_equal 179_494
    _(res[1][:attrs]).must_be_empty
  end

  it "should parse attrs" do
    raw = <<~METRICS
      kafka_server_socket_server_metrics{network_processor="8",listener="sasl_ssl",key="connection-count"} 0.0
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.size).must_equal 1
    _(res.first[:key]).must_equal "kafka_server_socket_server_metrics"
    _(res.first[:value]).must_equal 0.0
    attrs = {
      network_processor: "8",
      listener: "sasl_ssl",
      key: "connection-count"
    }
    _(res.first[:attrs]).must_equal attrs
  end

  it "should parse attrs with spaces" do
    raw = <<~METRICS
      kafka_server_socket_server_metrics{network_processor = "8" , listener="sasl_ssl" ,key="connection-count"} 0.0
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.size).must_equal 1
    _(res.first[:key]).must_equal "kafka_server_socket_server_metrics"
    _(res.first[:value]).must_equal 0.0
    attrs = {
      network_processor: "8",
      listener: "sasl_ssl",
      key: "connection-count"
    }
    _(res.first[:attrs]).must_equal attrs
  end

  it "should skip comments" do
    raw = <<~METRICS
      # HELP .................
      # TYPE ...................
      kafka_server_socket_server_metrics{network_processor="8",listener="sasl_ssl",key="connection-count"} 0.0
    METRICS

    res = PrometheusParser.parse(raw)
    _(res.size).must_equal 1
    _(res.first[:key]).must_equal "kafka_server_socket_server_metrics"
  end

  it "should raise error on bad key" do
    raw = <<~METRICS
      kafka!_server_socket_server_metrics 0.0
    METRICS
    assert_raises PrometheusParser::Invalid do
      PrometheusParser.parse(raw)
    end
  end

  it "should handle NaN values" do
    raw = <<~METRICS
      kafka_server_socket_server_metrics NaN
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:value]).must_be_same_as Float::NAN
  end

  it "should handle 8.123213E-28" do
    raw = <<~METRICS
      kafka_server_socket_server_metrics 8.123213E-28
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:value]).must_equal 8.123213e-28
  end

  it "should handle decimals values in attributes" do
    raw = <<~METRICS
      concurrent_request_processing_in_commit_processor{quantile="0.5",} NaN
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:attrs][:quantile]).must_equal "0.5"
    _(res.first[:value]).must_be_same_as Float::NAN
  end

  it "should handle space values in attributes" do
    raw = <<~METRICS
      jvm_memory_pool_allocated_bytes_total{pool="CodeHeap 'non-profiled nmethods'",} 2387840.0
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:attrs][:pool]).must_equal "CodeHeap 'non-profiled nmethods'"
    _(res.first[:value]).must_equal 2_387_840.0
  end

  it "should handle plus (+) values in attributes" do
    raw = <<~METRICS
      jvm_info{version="11.0.16+8-post-Debian-1deb11u1",vendor="Debian",runtime="OpenJDK Runtime Environment",} 1.0
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:attrs][:version]).must_equal "11.0.16+8-post-Debian-1deb11u1"
  end

  it "should handle tilde (~) values in attributes " do
    raw = <<~METRICS
      jvm_info{runtime="OpenJDK Runtime Environment",vendor="Private Build",version="1.8.0_362-8u362-ga-0ubuntu1~20.04.1-b09",} 1.0
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:attrs][:version]).must_equal "1.8.0_362-8u362-ga-0ubuntu1~20.04.1-b09"
  end

  it "should handle at (@) values in attributes" do
    raw = <<~METRICS
      rabbitmq_identity_info{rabbitmq_node="rabbit@dev-tough-coral-possum-01",rabbitmq_cluster="dev-tough-coral-possum",rabbitmq_cluster_permanent_id="rabbitmq-cluster-id-pEePKCwB2qV3TPZ2aVeW-w"} 1
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:attrs][:rabbitmq_node]).must_equal "rabbit@dev-tough-coral-possum-01"
    _(res.first[:value]).must_equal 1
  end

  it "should handle semi-colon (;) values in attributes" do
    raw = <<~METRICS
      telemetry_scrape_duration_seconds_count{registry="detailed",content_type="text/plain;"} 200
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:attrs][:content_type]).must_equal "text/plain;"
    _(res.first[:value]).must_equal 200
  end

  it "should handle equal sign (=) values in attributes" do
    raw = <<~METRICS
      telemetry_scrape_duration_seconds_count{registry="detailed",content_type="text/plain; version=0.0.4"} 200
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:attrs][:content_type]).must_equal "text/plain; version=0.0.4"
    _(res.first[:value]).must_equal 200
  end

  it "should handle less than (<) and more than (>) values in attributes" do
    raw = <<~METRICS

      rabbitmq_detailed_connection_channels{channel="<0.9648.14>"} 0

    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:attrs][:channel]).must_equal "<0.9648.14>"
    _(res.first[:value]).must_equal 0
  end

  it "should handle extra newlines" do
    raw = <<~METRICS

      response_packet_get_children_cache_hits{version="1.0.0"} 0.0

    METRICS
    res = PrometheusParser.parse(raw)
    _(res.size).must_equal 1
    _(res.first[:key]).must_equal "response_packet_get_children_cache_hits"
    _(res.first[:value]).must_equal 0.0
    _(res.first[:attrs]).must_equal({ version: "1.0.0" })
  end

  it "should skip quoted values in attributes" do
    raw = <<~METRICS
      rabbitmq_detailed_queue_messages_ready{vhost="xxxxxxxx",queue="F56211164662"} 0
      rabbitmq_detailed_queue_messages_ready{vhost="xxxxxxxx",queue=""{"command":"OPEN"}""} 5
      rabbitmq_detailed_queue_messages_ready{vhost="xxxxxxxx",queue="F55211161384"} 0
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:attrs][:queue]).must_equal "F56211164662"
    _(res.last[:attrs][:queue]).must_equal "F55211161384"
    _(res.size).must_equal 2
  end

  # Some RabbitMQ versions can respond with "unknown"
  # https://github.com/rabbitmq/rabbitmq-server/discussions/5143
  it "should fix broken values from RabbitMQ (unknown -> NaN)" do
    raw = <<~METRICS
      rabbitmq_detailed_disk_space_available_bytes unknown
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:key]).must_equal "rabbitmq_detailed_disk_space_available_bytes"
    _(res.first[:value]).must_be_same_as Float::NAN
  end
end
