require_relative 'lib/cloudsap/version'

Gem::Specification.new do |spec|
  spec.name          = 'cloudsap'
  spec.version       = Cloudsap::VERSION
  spec.authors       = ['Brian Warsing']
  spec.email         = ['dayglojesus@gmail.com']

  spec.summary       = %{Kubernetes CloudServiceAccount controller}
  spec.description   = %{Controller that manages custom resource CloudServiceAccount}
  spec.homepage      = %{https://github.com/dayglojesus/cloudsap}

  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri']    = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/dayglojesus/cloudsap'
  spec.metadata['changelog_uri']   = 'https://github.com/dayglojesus/cloudsap/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rake', '>= 13.0.1'
  spec.add_dependency 'erb'
  spec.add_dependency 'rack', '~> 2.2'
  spec.add_dependency 'thin', '~> 1.7'
  spec.add_dependency 'thor', '~> 1.0'
  spec.add_dependency 'kubeclient', '~> 4.9'
  spec.add_dependency 'prometheus-client', '~> 2.1'
  spec.add_dependency 'aws-sdk-iam', '~> 1.44'
  spec.add_dependency 'aws-sdk-eks', '~> 1.41'

  spec.add_development_dependency 'pry', '>= 0.13'
  spec.add_development_dependency 'pry-remote',  '>= 0.1'
  spec.add_development_dependency 'rerun', '>= 0.13'
  spec.add_development_dependency 'rspec', '>= 3.0'
  spec.add_development_dependency 'rspec-command', '>= 1.0'
  spec.add_development_dependency 'rubocop', '>= 0.71.0'
end
