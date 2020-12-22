# frozen_string_literal: true

module Cloudsap
  class CloudServiceAccount
    include Concurrent::Async
    include Common
    include Kubernetes
    include Aws

    attr_reader :stack, :metrics, :client, :event, :type, :object, :metadata,
      :annotations, :provider_id, :status

    def self.load(stack, metrics, client, event)
      new(stack, metrics, client, event)
    end

    def initialize(stack, metrics, client, event)
      @stack   = stack
      @metrics = metrics
      @client  = client
      refresh(event)
    end

    def name
      metadata[:name]
    end

    def namespace
      metadata[:namespace]
    end

    def generation
      metadata[:generation]
    end

    def resource_version
      metadata[:resourceVersion]
    end

    def cluster_id
      options[:cluster_id]
    end

    def added
      metrics.added if create
    ensure
      stack.delete(name)
    end

    def modified
      return false unless spec_changed?
      metrics.modified if update
    ensure
      stack.delete(name)
    end

    def deleted
      metrics.deleted if delete
    ensure
      stack.delete(name)
    end

    def error
      metrics.error
    ensure
      stack.delete(name)
    end

    def refresh(event)
      @event       = event.to_h
      @type        = @event[:type]
      @object      = @event[:object]
      @metadata    = @object[:metadata]
      @status      = @object[:status] ||= {}
      @annotations = @metadata[:annotations]
      @provider_id = @event[:object][:spec][:cloudProvider].to_sym
    rescue => error
      log_exception(error)
    end

    def status=(data)
      status.merge!(data)
    end

    private

    def merge_opts
      {
        merge_hash_arrays: true,
        overwrite_arrays: true,
      }
    end

    def update_status
      data = {
        status: {
          observed: {
            generation: generation,
            resourceVersion: resource_version,
          }
        }
      }
      status.deep_merge(data)
      client.patch_cloud_service_account_status(name, status, namespace)
    end

    def create
      logger.info("#{__callee__.upcase}, #{self.class}: #{namespace}/#{name}")
      sa = ServiceAccount.new(self)
      sa.apply
      role = IamRole.new(self)
      role.apply
    rescue => error
      log_exception(error)
      show_backtrace(error)
    ensure
      update_status
    end

    alias update create

    def delete
      role = IamRole.new(self)
      role.delete
      sa = ServiceAccount.new(self)
      sa.delete
      logger.info("#{__callee__.upcase}, #{self.class}: #{namespace}/#{name}")
    rescue => error
      log_exception(error)
      show_backtrace(error)
    end

    def spec_changed?
      generation != status[:observed][:generation]
    end
  end
end
