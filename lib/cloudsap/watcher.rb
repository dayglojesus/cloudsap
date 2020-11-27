# frozen_string_literal: true

module Cloudsap
  class Watcher
    attr_reader :api_group, :api_version, :client

    include Common

    def self.run(api_group, api_version, metrics)
      new(api_group, api_version, metrics).watch
    end

    # apiVersion: k8s.groundstate.io/v1alpha1
    def initialize(api_group, api_version, metrics)
      @metrics     = metrics
      @api_group   = api_group
      @api_version = api_version
      @client      = csa_client
    end

    def watch
      version = @client.get_cloud_service_accounts.resourceVersion
      @client.watch_cloud_service_accounts(resource_version: version) do |res|
        self.send(res.type.downcase.to_sym, res)
      end
    end

    def csa_load(resource)
      @csa = CloudServiceAccount.load(client, resource)
    end

    def added(resource)
      # pp resource
      csa_load(resource)
      @metrics.added if @csa.create
    end

    def modified(resource)
      # pp resource
      csa_load(resource)
      @metrics.modified if @csa.update
    end

    def deleted(resource)
      # pp resource
      csa_load(resource)
      @metrics.deleted if @csa.delete
    end

    def error(resource)
      # pp resource
      @metrics.error
    end

    def config
      kubeconfig
    end
  end
end
