# frozen_string_literal: true

module Cloudsap
  module Aws
    class IamRoleError < StandardError; end

    class IamRole
      include Common

      attr_reader :csa, :object, :sa_name, :sa_namespace, :client

      def self.load(csa)
        new(csa)
      end

      def initialize(csa)
        @csa          = csa
        @object       = csa.object.to_h
        @sa_name      = object[:metadata][:name]
        @sa_namespace = object[:metadata][:namespace]
        @client       = iam_client
      end

      def name
        @name ||= "#{cluster_name}-sa-#{sa_namespace}-#{sa_name}"
      end

      def apply
        require 'pry'
        binding.pry

        resp = create_role

        return resp if resp.successful?
        raise IamRoleError.new("Error creating IAM Role: #{resp.error}")
      end

      def delete
      end

      private

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
          role_name: name,
          assume_role_policy_document: generate_assume_role_policy_document,
          description: "IAM Role for ServiceAccount #{sa_namespace}/#{sa_name}",
          max_session_duration: 1,
          # permissions_boundary: "arnType",
          tags: [
            {
              key: 'Name',
              value: name, # required
            },
          ],
        })
      end
    end
  end
end

