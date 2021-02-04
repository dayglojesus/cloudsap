# frozen_string_literal: true

module Cloudsap
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    no_commands do
      def setup_rack(registry)
        Rack::Builder.new do
          use Rack::Deflater
          use Prometheus::Middleware::Exporter, registry: registry
          map '/health' do
            run ->(_env) { [200, { 'Content-Type' => 'text/html' }, ['OK']] }
          end
        end
      end

      def start_watch(api_group, api_version, metrics)
        Thread.report_on_exception = true
        Thread.abort_on_exception = true
        Thread.new do
          Cloudsap::Watcher.run(api_group, api_version, metrics)
        rescue StandardError => e
          Cloudsap::Common.log_exception(e)
          Cloudsap::Common.show_backtrace(e)
          sleep 5
          metrics.restart
          retry
        end
      end
    end

    desc 'controller', 'Run Cloudsap controller'
    option :aws_region,   type: :string,  default: ENV['AWS_REGION'], required: true
    option :cluster_name, type: :string,  default: ENV['CLOUDSAP_CLUSTER_NAME'], required: true
    option :oidc_issuer,  type: :string,  default: ENV['CLOUDSAP_OIDC_ISSUER'], required: false
    option :debug,        type: :boolean, default: (ENV['CLOUDSAP_DEBUG'] || false)
    def controller
      Cloudsap::Common.setup(options)

      registry = Prometheus::Client.registry
      metrics  = Cloudsap::Metrics.new(registry)

      start_watch(API_GROUP, API_VERSION, metrics)

      Thin::Logging.logger = Cloudsap::Common.logger
      Rack::Server.start(app: setup_rack(registry))
    end
  end
end
