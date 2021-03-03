# frozen_string_literal: true

module Cloudsap
  module Kubernetes
    class Config
      include Common

      attr_reader :data

      def initialize(path = nil)
        @path = path.to_s
        @data = load(@path)
      end

      def api_endpoint
        data.context.api_endpoint
      end

      def ssl_options
        data.context.ssl_options
      end

      def auth_options
        data.context.auth_options
      end

      def defaults
        @defaults ||= RecursiveOpenStruct.new(cluster_defaults)
      end

      private

      def load(path)
        return defaults if path.empty?

        Kubeclient::Config.read(path) if File.exist?(path)
      rescue StandardError => e
        logger.fatal(e.message)
        abort
      end

      def cluster_defaults
        {
          context: {
            api_endpoint: 'https://kubernetes.default.svc',
            ssl_options: {
              ca_file: '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt'
            },
            auth_options: {
              bearer_token_file: '/var/run/secrets/kubernetes.io/serviceaccount/token'
            }
          }
        }
      end
    end
  end
end
