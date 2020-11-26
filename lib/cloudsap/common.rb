# frozen_string_literal: true

module Cloudsap
  module Common
    class << self
      attr_reader :options

      def aws_iam_client
        @iam_client = Aws::IAM::Client.new(
          region: options.aws_region,
        )
      end

      def aws_eks_client
        @eks_client = Aws::EKS::Client.new(
          region: aws_region,
        )
      end

      def aws_sts_client
        @sts_client = Aws::STS::Client.new(
          region: aws_region,
        )
      end

      def options=(hash)
        @options = hash.transform_keys(&:to_sym)
      end
    end

    def sanitize_resource(object)
      filtered = Marshal.load( Marshal.dump(object) )
      filtered.tap do |dat|
        dat[:metadata].delete(:generation)
        dat[:metadata].delete(:managedFields)
        dat[:metadata][:annotations].delete(:"kubectl.kubernetes.io/last-applied-configuration")
      end
    end

    def kubeconfig
      config = ENV['KUBECONFIG'] || File.expand_path('~/.kube/config')
      Kubeclient::Config.read(config)
    end

    def csa_client
      config = kubeconfig
      Kubeclient::Client.new(
        File.join(config.context.api_endpoint, 'apis', api_group),
        api_version,
        ssl_options: config.context.ssl_options,
        auth_options: config.context.auth_options,
      )
    end

    def sa_client
      config = kubeconfig
      Kubeclient::Client.new(
        config.context.api_endpoint,
        'v1',
        ssl_options: config.context.ssl_options,
        auth_options: config.context.auth_options
      )
    end
  end
end
