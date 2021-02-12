# frozen_string_literal: true

require_relative 'lib/cloudsap/version'

Gem::Specification.new do |spec|
  spec.name          = 'cloudsap'
  spec.version       = Cloudsap::VERSION
  spec.authors       = ['Brian Warsing']
  spec.email         = ['dayglojesus@gmail.com']

  spec.summary       = %(Kubernetes CloudServiceAccount controller)
  spec.description   = %(Controller that manages custom resource CloudServiceAccount)
  spec.homepage      = %(https://github.com/dayglojesus/cloudsap)

  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.5.0')

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri']    = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/dayglojesus/cloudsap'
  spec.metadata['changelog_uri']   = 'https://github.com/dayglojesus/cloudsap/CHANGELOG.md'

  (spec.files = %w[
    lib/**/*.rb
    bin/*
    exe/*
    *.md
    *.rdoc
    *.gemspec
    LICENSE.txt
  ].collect do |pattern|
    Dir.glob(pattern)
  end).flatten.compact.sort.uniq

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'aws-sdk-eks', '~> 1.41'
  spec.add_dependency 'aws-sdk-iam', '~> 1.44'
  spec.add_dependency 'concurrent-ruby', '~> 1.1'
  spec.add_dependency 'deep_merge', '~> 1.2'
  spec.add_dependency 'erb', '~> 2.2'
  spec.add_dependency 'kubeclient', '~> 4.9'
  spec.add_dependency 'prometheus-client', '~> 2.1'
  spec.add_dependency 'rack', '~> 2.2'
  spec.add_dependency 'rake', '>= 13.0.1'
  spec.add_dependency 'thin', '~> 1.7'
  spec.add_dependency 'thor', '~> 1.0'

  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'pry', '>= 0.13'
  spec.add_development_dependency 'pry-remote', '>= 0.1'
  spec.add_development_dependency 'rerun', '>= 0.13'
  spec.add_development_dependency 'rubocop', '~> 1.9.0'
  spec.add_development_dependency 'rubocop-minitest', '~> 0.10.3'
end
