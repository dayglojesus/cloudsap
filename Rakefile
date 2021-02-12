require 'bundler'
require 'open3'
require 'uri'
require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task :default => :test

def bundler
  @bundler ||= Bundler::GemHelper.new
end

def execute(cmd)
  Open3.popen2e(ENV, cmd) do |stdin, stdout_err, wait_thru|
    puts $_ while stdout_err.gets
    wait_thru.value.exitstatus
  end
end

def name
  bundler.gemspec.name
end

def version
  bundler.gemspec.version
end

desc "Lint gem"
task :lint do
  exit(execute('bundle exec rubocop lib'))
end
