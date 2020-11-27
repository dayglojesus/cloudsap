# frozen_string_literal: true

module Cloudsap
  module Common
    class AwsEksClientError < StandardError; end
    class AwsIamClientError < StandardError; end
    class AwsStsClientError < StandardError; end

    class << self
      attr_reader :options, :logger

      def logger
        @logger ||= Logger.new(STDOUT).tap do |dat|
          dat.progname  = PROGRAM_NAME
          dat.formatter = proc do |severity, datetime, progname, msg|
            {
              level: severity,
              timestamp: datetime.strftime(DATETIME_FMT),
              app: progname,
              message: msg.chomp
            }.to_json + $/
          end
        end
      end

      def aws_iam_client
        @iam_client ||= Aws::IAM::Client.new(
          region: options.aws_region,
        )
      end

      def aws_eks_client
        @eks_client ||= Aws::EKS::Client.new(
          region: aws_region,
        )
      end

      def aws_sts_client
        @sts_client ||= Aws::STS::Client.new(
          region: aws_region,
        )
      end

      def options=(hash)
        @options = hash.transform_keys(&:to_sym)
      end
    end

    def options
      Common.options
    end

    def logger
      Common.logger
    end

    def oidc_provider
      eks_client = Common.aws_eks_client
      resp       = eks_client.describe_cluster(name: cluster_name)
      if resp.successful?
        uri = URI.parse(resp.cluster.identity.oidc.issuer)
        return File.join(uri.host, uri.path)
      end
      raise AwsEksClientError.new("Error fetching OIDC provider: #{resp.error}")
    end

    def account_id
      sts_client = Common.aws_sts_client
      resp       = sts_client.get_caller_identity
      return resp.account if resp.successful?
      raise AwsStsClientError.new("Error fetching AWS account id: #{resp.error}")
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

    def program_label
      [PROGRAM_NAME, API_VERSION].join('_')
    end
  end
end
