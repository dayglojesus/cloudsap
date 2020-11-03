# frozen_string_literal: true

module Cloudsap
  class CloudServiceAccount
    include Common

    attr_reader :resource, :type, :object, :provider_id

    def self.load(resource)
      new(resource)
    end

    def initialize(resource)
      @resource    = resource.to_h
      @type        = @resource[:type]
      @object      = @resource[:object]
      @provider_id = @resource[:object][:spec][:cloudProvider].to_sym
      @sa_client   = sa_client
    end

    def create
      # cluster_name + "sa" + namespace + sa_name
      # create IAM Role
      # create inline policy
      # attach specified policies
      # create k8s SA
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

    private

    def iam_role_name(object)
      iam_role_name = %W[
        #{options[:cluster_id]}
        sa
        #{object[:metadata][:namespace]}
        #{object[:metadata][:name]}
      ].join('-')
    end
  end
end
