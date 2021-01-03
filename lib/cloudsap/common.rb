# frozen_string_literal: true

module Cloudsap
  module Common
    class AwsEksClientError < StandardError; end
    class AwsIamClientError < StandardError; end
    class AwsStsClientError < StandardError; end

    class << self
      attr_reader :options, :aws_iam_client, :aws_eks_client, :aws_sts_client,
                  :oidc_provider, :account_id

      alias iam_client aws_iam_client
      alias eks_client aws_eks_client
      alias sts_client aws_sts_client

      def setup(options_hash)
        @options = OpenStruct.new(options_hash)

        logger.info 'Initializing ...'

        @aws_sts_client = init_aws_sts_client
        @aws_iam_client = init_aws_iam_client
        @aws_eks_client = begin
          init_aws_eks_client
        rescue StandardError
          nil
        end
      rescue StandardError => e
        logger.fatal(e.message)
        abort
      end

      def logger
        @logger ||= init_logger
      end

      def log_exception(obj, level = :error)
        logger.send(level, "#{obj.class}: #{obj.message} [#{error_line(obj)}]")
      end

      def show_backtrace(obj)
        warn obj.backtrace if options.debug
      end

      def cluster_name
        options.cluster_name
      end

      private

      def error_line(error)
        line = error.backtrace.find { |l| l =~ %r{cloudsap/lib/cloudsap} }
        file, line_num, _meth = line.split(':')
        "#{File.basename(file)}:#{line_num}"
      end

      # rubocop:disable Style/SpecialGlobalVars
      def init_logger
        Logger.new($stdout).tap do |dat|
          dat.level     = @options.debug ? Logger::DEBUG : Logger::INFO
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
      # rubocop:enable Style/SpecialGlobalVars

      def init_aws_sts_client
        client = ::Aws::STS::Client.new(region: options.aws_region)
        resp   = client.get_caller_identity
        if resp.successful?
          @account_id = resp.account
          logger.debug '::Aws::STS::Client initialized'
          return client
        end
        raise AwsEksClientError, 'Initialization failed!'
      end

      def init_aws_eks_client
        client = ::Aws::EKS::Client.new(region: options.aws_region)
        resp   = client.describe_cluster(name: cluster_name)
        if resp.successful?
          uri = URI.parse(resp.cluster.identity.oidc.issuer)
          @oidc_provider = File.join(uri.host, uri.path)
          logger.debug '::Aws::EKS::Client initialized'
          return client
        end
        raise AwsEksClientError, 'Initialization failed!'
      end

      def init_aws_iam_client
        client = ::Aws::IAM::Client.new(region: options.aws_region)
        resp   = client.list_roles(path_prefix: '/', max_items: 1)
        if resp.successful?
          logger.debug '::Aws::IAM::Client initialized'
          return client
        end
        raise AwsIamClientError, 'Initialization failed!'
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
        auth_options: config.context.auth_options
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

    def method_missing(method_name, *args)
      super unless Common.respond_to?(method_name)
      Common.send(method_name, *args)
    end

    def respond_to_missing?(method_name, include_private = false)
      Common.respond_to?(method_name) || super
    end
  end
end
