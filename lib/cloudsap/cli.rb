# frozen_string_literal: true

module Cloudsap
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    # rubocop:disable Metrics/BlockLength
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
        future_proofer(watcher.futures).execute
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
    # rubocop:enable Metrics/BlockLength

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

    desc 'install COMPONENT', 'Install Cloudsap IRSA or generate install manifests'
    option :aws_region,   type: :string, default: ENV['AWS_REGION'], required: true
    option :cluster_name, type: :string, default: ENV['CLOUDSAP_CLUSTER_NAME'], required: true
    option :namespace,    type: :string, default: ENV['CLOUDSAP_NAMESPACE'], required: true
    option :kubeconfig,   type: :string, default: ENV['KUBECONFIG'], required: false
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    def install(component)
      $stdout.sync = true
      Cloudsap::Common.options = options
      Cloudsap::Common.set_plaintext_logger
      case component.to_sym
      when :irsa
        Cloudsap::Common.setup(options)
        Cloudsap::Aws::IamRole.irsa(PROGRAM_NAME, options.namespace).apply
      when :crd
        IO.foreach("#{Cloudsap::Common.assets}/cloudserviceaccount.yaml") { |line| puts line }
      when :full
        values = {
          aws_region: options.aws_region,
          cluster_name: options.cluster_name,
          namespace: options.namespace,
          account_id: Cloudsap::Common.account_id
        }
        manifest = "#{Cloudsap::Common.assets}/full_install_manifest.erb"
        puts ERB.new(File.read(manifest)).result_with_hash(values)
      else
        msg = %(Invalid argument -- I don't know how to install: #{component})
        Cloudsap::Common.logger.fatal(msg)
        exit 1
      end
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
  end
end
