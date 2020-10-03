# frozen_string_literal: true

module Cloudsap
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    no_commands do
    end

    desc 'controller', 'Run Cloudsap controller'
    option :aws_region, type: :string,  default: ENV['AWS_REGION'], required: true
    option :cluster_id, type: :string,  default: ENV['CLOUDSAP_CLUSTER_ID'], required: true
    option :provider,   type: :string,  default: (ENV['CLOUDSAP_PROVIDER'] || 'aws')
    option :debug,      type: :boolean, default: (ENV['CLOUDSAP_DEBUG']    || false)
    def controller
      registry = Prometheus::Client.registry
      metrics  = Cloudsap::Metrics.new(registry)

      Thread.report_on_exception = true
      Thread.abort_on_exception = true
      Thread.new do
        begin
          Cloudsap::Watcher.run(API_GROUP, API_VERSION, metrics)
        rescue => error
          puts error.message
          puts error.backtrace if debug
          sleep 5
          metrics.restart
          retry
        end
      end

      app = Rack::Builder.new do
        use Rack::Deflater
        use Prometheus::Middleware::Exporter, registry: registry
        map '/health' do
          run ->(env) { [200, {"Content-Type" => "text/html"}, ["OK"]] }
        end
      end

      Rack::Server.start(app: app)
    end
  end
end
