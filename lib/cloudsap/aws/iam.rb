# frozen_string_literal: true

module Cloudsap
  module Aws
    class IamRoleError < StandardError; end

    class IamRole
      include Common

      def initialize(object)
        @object       = object
        @sa_name      = object[:metadata][:name]
        @sa_namespace = object[:metadata][:namespace]
      end

      def create
        resp = create_role

        return resp if resp.successful?
        raise IamRoleError.new("Error creating IAM Role: #{resp.error}")
      end

      def update
      end

      def delete
      end

      private
      attr_reader :sa_name, :sa_namespace

      def client
        Common.aws_iam_client
      end

      def options
        Common.options
      end

      def cluster_name
        options[:cluster_name]
      end

      def iam_role_name
        "#{cluster_name}-sa-#{sa_namespace}-#{sa_name}"
      end

      def oidc_provider
        eks_client = Common.aws_eks_client
        resp       = eks_client.describe_cluster(name: cluster_name)
        if resp.successful?
          uri = URI.parse(resp.cluster.identity.oidc.issuer)
          return File.join(uri.host, uri.path)
        end
        raise IamRoleError.new("Error fetching OIDC provider: #{resp.error}")
      end

      def account_id
        sts_client = Common.aws_sts_client
        resp       = sts_client.get_caller_identity
        return resp.account if resp.successful?
        raise IamRoleError.new("Error fetching AWS account id: #{resp.error}")
      end

      def generate_assume_role_policy_document
        {
          'Version' => '2012-10-17',
          'Statement' => [
            {
              'Effect' => 'Allow',
              'Principal' => {
                'Federated' => "arn:aws:iam::#{account_id}:oidc-provider/#{oidc_provider}"
              },
              'Action' => 'sts:AssumeRoleWithWebIdentity',
              'Condition' => {
                'StringEquals' => {
                  "#{oidc_provider}:sub" => "system:serviceaccount:#{sa_namespace}:#{sa_name}"
                }
              }
            }
          ]
        }.to_json
      end

      def generate_role_policy
        {
          'Version' => '2012-10-17',
          'Statement' => {
            'Effect' => 'Allow',
            'Action' => 's3:*',
            'Resource' => '*',
          }
        }
      end

      def put_role_policy
        resp = client.put_role_policy({
          role_name: iam_role_name,
          policy_name: iam_role_name,
          policy_document: generate_role_policy,
        })
      end

      def attach_role_policy
        resp = client.attach_role_policy({
          role_name: iam_role_name,
          policy_arn: "arn:aws:iam::aws:policy/ReadOnlyAccess",
        })
      end

      def create_role
        resp = client.create_role({
          path: '/',
          role_name: iam_role_name,
          assume_role_policy_document: generate_assume_role_policy_document,
          description: "IAM Role for ServiceAccount #{sa_namespace}/#{sa_name}",
          max_session_duration: 1,
          # permissions_boundary: "arnType",
          tags: [
            {
              key: 'Name',
              value: iam_role_name, # required
            },
          ],
        })
      end
    end
  end
end

