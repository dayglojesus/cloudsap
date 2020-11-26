# frozen_string_literal: true

module Cloudsap
  module Kubernetes
    class ServiceAccount
      include Common

      attr_reader :resource, :type, :object, :client

      def self.load(resource)
        new(resource)
      end

      def initialize(resource)
        @resource = resource.to_h
        @type     = @resource[:type]
        @object   = @resource[:object]
        @client   = sa_client
      end

      def create
        binding.pry
      end

      def read
      end

      def update
      end

      def delete
      end

      def options
        Common.options
      end
    end
  end
end
