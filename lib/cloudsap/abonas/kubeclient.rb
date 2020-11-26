module Kubeclient
  module ClientMixin
    def discover
      load_entities
      define_entity_methods
      @entities.values.each do |entity|
        define_singleton_method("get_#{entity.method_names[0]}_status") \
        do |name, namespace = nil, opts = {}|
          get_entity(entity.resource_name, name, namespace, opts)
        end
        define_singleton_method("patch_#{entity.method_names[0]}_status") \
        do |name, patch, namespace = nil|
          patch_entity_status(entity.resource_name, name, patch, 'merge-patch+json', namespace)
        end
      end
      @discovered = true
    end

    def patch_entity_status(resource_name, name, patch, strategy, namespace)
      strategy  = 'application/merge-patch+json'
      ns_prefix = build_namespace_prefix(namespace)
      uri       = ns_prefix + resource_name + "/#{name}/status"
      headers   = { 'Content-Type' => "#{strategy}" }.merge(@headers)
      response = handle_exception do
        rest_client[uri].patch(patch.to_json, headers)
      end
      format_response(@as, response.body)
    end

    def get_entity_status(resource_name, name, namespace = nil, options = {})
      ns_prefix = build_namespace_prefix(namespace)
      response = handle_exception do
        rest_client[ns_prefix + resource_name + "/#{name}/status"]
          .get(@headers)
      end
      format_response(options[:as] || @as, response.body)
    end
  end
end