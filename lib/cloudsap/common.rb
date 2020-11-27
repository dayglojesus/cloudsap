# frozen_string_literal: true

module Cloudsap
  module Common
    class AwsEksClientError < StandardError; end
    class AwsIamClientError < StandardError; end
    class AwsStsClientError < StandardError; end

    class << self
      attr_reader :options, :logger, :aws_iam_client, :aws_eks_client,
        :aws_sts_client, :oidc_provider, :account_id

      def setup(options_hash)
        logger.info 'Initializing ...'

        @options        = OpenStruct.new(options_hash)
        @aws_sts_client = init_aws_sts_client
        @aws_iam_client = init_aws_iam_client
        @aws_eks_client = init_aws_eks_client rescue nil
      rescue => error
        logger.fatal(error.message)
        abort
      end

      def logger
        @logger ||= init_logger
      end

      def cluster_name
        options.cluster_name
      end

      private

      def init_logger
        logger = Logger.new(STDOUT).tap do |dat|
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

      def init_aws_sts_client
        client = ::Aws::STS::Client.new(region: options.aws_region)
        resp   = client.get_caller_identity
        if resp.successful?
          @account_id = resp.account
          logger.info '::Aws::STS::Client initialized'
          return client
        end
        raise AwsEksClientError.new('Initialization failed!')
      end

      def init_aws_eks_client
        client = ::Aws::EKS::Client.new(region: options.aws_region)
        resp   = client.describe_cluster(name: cluster_name)
        if resp.successful?
          uri = URI.parse(resp.cluster.identity.oidc.issuer)
          @oidc_provider = File.join(uri.host, uri.path)
          logger.info '::Aws::EKS::Client initialized'
          return client
        end
        raise AwsEksClientError.new('Initialization failed!')
      end

      def init_aws_iam_client
        client = ::Aws::IAM::Client.new(region: options.aws_region)
        resp   = client.list_roles(path_prefix: '/', max_items: 1)
        if resp.successful?
          logger.info '::Aws::IAM::Client initialized'
          return client
        end
        raise AwsIamClientError.new('Initialization failed!')
      end
    end

    def options
      Common.options
    end

    def logger
      Common.logger
    end

    def iam_client
      Common.aws_iam_client
    end

    def eks_client
      Common.aws_eks_client
    end

    def sts_client
      Common.aws_sts_client
    end

    def cluster_name
      Common.cluster_name
    end

    def oidc_provider
      Common.oidc_provider
    end

    def account_id
      Common.account_id
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
