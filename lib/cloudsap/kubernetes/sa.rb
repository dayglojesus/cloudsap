# frozen_string_literal: true

module Cloudsap
  module Kubernetes
    class ServiceAccount
      include Common

      attr_reader :csa, :object, :client

      def self.load(csa)
        new(csa)
      end

      def initialize(csa)
        @csa    = csa
        @object = csa.object.to_h
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
        if (resource = apply_service_account)
          update_status(resource)
          logger.info("APPLY, #{self.class}: #{namespace}/#{name}")
        end
      end

      def delete
        if delete_service_account
          logger.info("DELETE, #{self.class}: #{namespace}/#{name}")
        end
      end

      private

      def update_status(resource)
        filter = %i[name creationTimestamp resourceVersion uid]
        patch  = resource.metadata.to_h.slice(*filter)
        csa.status = { status: { serviceAccount: patch } }
      end

      def apply_service_account
        client.apply_service_account(service_account, field_manager: program_label)
      end

      def delete_service_account
        client.delete_service_account(name, namespace)
      end

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
            labels: labels
          },
          automountServiceAccountToken: automount_service_account_token,
          imagePullSecrets: image_pull_secrets
        }.compact
      end
    end
  end
end
