# frozen_string_literal: true

module Cloudsap
  class Metrics
    # rubocop:disable Layout/LineLength
    def initialize(registry)
      @registry = registry
      @added    = @registry.counter(:cloudsap_watcher_added, docstring: 'Count of CloudServiceAccounts added')
      @modified = @registry.counter(:cloudsap_watcher_modified, docstring: 'Count of CloudServiceAccounts modified')
      @deleted  = @registry.counter(:cloudsap_watcher_deleted, docstring: 'Count of CloudServiceAccounts deleted')
      @error    = @registry.counter(:cloudsap_watcher_error, docstring: 'Count of CloudServiceAccounts errors')
      @restart  = @registry.counter(:cloudsap_watcher_restart, docstring: 'Count of CloudsapWatcher restarts')
    end
    # rubocop:enable Layout/LineLength

    %i[added modified deleted error restart].each do |meth|
      define_method(meth) { instance_variable_get("@#{meth}").increment }
    end
  end
end
