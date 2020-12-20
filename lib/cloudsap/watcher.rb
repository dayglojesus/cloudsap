# frozen_string_literal: true

module Cloudsap
  class Watcher
    attr_reader :api_group, :api_version, :client, :stack, :metrics

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
      @stack       = {}
    end

    def watch
      version = @client.get_cloud_service_accounts.resourceVersion
      @client.watch_cloud_service_accounts(resource_version: version) do |event|
        process_event(event)
      end
    end

    private

    def process_event(event)
      name      = event[:object][:metadata][:name]
      namespace = event[:object][:metadata][:namespace]
      operation = event[:type].downcase.to_sym
      identity  = "#{namespace}/#{name}"

      logger.info("#{event[:type]}, event for #{identity}")
      if stack[identity]
        stack[identity].refresh(event)
      else
        stack[identity] = csa_load(event)
      end

      stack[identity].async.send(operation)
    end

    def csa_load(event)
      CloudServiceAccount.load(stack, metrics, client, event)
    end
  end
end
