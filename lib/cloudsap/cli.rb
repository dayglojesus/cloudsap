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

      def future_proofer(futures)
        timer = Concurrent::TimerTask.new do
          futures.each_with_index do |future, index|
            if future.rejected?
              Cloudsap::Common.logger.error("#{future.class}: #{future.reason}")
            end
            futures.delete_at(index) if future.complete?
          end
        end
        timer.execution_interval = 1
        timer.timeout_interval   = 5
        timer
      end

      def start_watch(api_group, api_version, metrics)
        Thread.report_on_exception = true
        Thread.abort_on_exception = true
        watcher = Cloudsap::Watcher.new(api_group, api_version, metrics)
        checker = future_proofer(watcher.futures).execute
        Thread.new do
          watcher.watch
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
    option :kubeconfig,   type: :string,  default: ENV['KUBECONFIG'], required: false
    option :debug,        type: :boolean, default: (ENV['CLOUDSAP_DEBUG'] || false)
    def controller
      $stdout.sync = true

      ENV['RACK_ENV'] = 'production'

      Cloudsap::Common.setup(options)

      registry = Prometheus::Client.registry
      metrics  = Cloudsap::Metrics.new(registry)

      start_watch(API_GROUP, API_VERSION, metrics)

      Thin::Logging.logger = Cloudsap::Common.logger
      Rack::Server.start(app: setup_rack(registry))
    end
  end
end
