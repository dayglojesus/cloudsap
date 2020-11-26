# frozen_string_literal: true

module Cloudsap
  class CloudServiceAccount
    include Common
    include Kubernetes
    include Aws

    attr_reader :client, :resource, :type, :object, :provider_id

    def self.load(client, resource)
      new(client, resource)
    end

    def initialize(client, resource)
      @client      = client
      @resource    = resource.to_h
      @type        = @resource[:type]
      @object      = @resource[:object]
      @provider_id = @resource[:object][:spec][:cloudProvider].to_sym
    end

    def name
      object[:metadata][:name]
    end

    def namespace
      object[:metadata][:namespace]
    end

    def cluster_id
      options[:cluster_id]
    end

    def create
      binding.pry
      # @client.patch_cloud_service_account_status 'demo01', , 'default'

      # sa = ServiceAccount.new(object)
      # sa.create
      # role = Aws::IamRole.new

      # create_role (unless exists?)
      # put_role_policy (unless exists?)
      # attach_role_policy (for each unless policy attached?)
      # create  SA
      # create CSA
    end

    def read
    end

    def update
      binding.pry
    end

    def delete
    end

    def options
      Common.options
    end

    private

    def status
      @client.get_cloud_service_account(name, namespace)
    end

    def status=(status)
      @client.patch_cloud_service_account_status(name, status, namespace)
    end
  end
end
