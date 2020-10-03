# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in cloudsap.gemspec
gemspec

git_source(:github) {|repo_name| "https://github.com/#{repo_name}"}

gem 'rake'
gem 'rack'
gem 'thin'
gem 'thor'
gem 'kubeclient'
gem 'prometheus-client'
gem 'aws-sdk-iam'
gem 'aws-sdk-eks'

group :test, :development do
  gem 'pry'
  gem 'pry-remote'
  gem 'rerun'
  gem 'rspec'
  gem 'rspec-command'
  gem 'rubocop'
end
