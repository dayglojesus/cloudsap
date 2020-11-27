# frozen_string_literal: true

module Cloudsap
  module Kubernetes
    class ServiceAccount
      include Common

      attr_reader :object, :client

      def self.load(object)
        new(object)
      end

      def initialize(object)
        @object = object.to_h
        @client = sa_client
      end

      def name
        object[:metadata][:name]
      end

      def namespace
        object[:metadata][:namespace]
      end

      def automount_service_account_token
        object.dig(:serviceAccountOptions, :automountServiceAccountToken)
      end

      def image_pull_secrets
        object.dig(:serviceAccountOptions, :imagePullSecrets)
      end

      def annotations
        {}
      end

      def labels
        {}
      end

      def apply
        client.apply_service_account(service_account, field_manager: program_label)
      end

      def delete
        client.delete_service_account(name, namespace)
      end

      private

      def service_account
        Kubeclient::Resource.new(generate_service_account)
      end

      def generate_service_account
        {
          apiVersion: 'v1',
          kind: 'ServiceAccount',
          metadata: {
            name: name,
            namespace: namespace,
            annotations: annotations,
            labels: labels,
          },
          automountServiceAccountToken: automount_service_account_token,
          imagePullSecrets: image_pull_secrets
        }.compact
      end
    end
  end
end
