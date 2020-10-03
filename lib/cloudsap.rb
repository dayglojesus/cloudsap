require 'pry'

require 'thor'
require 'time'
require 'date'
require 'yaml'
require 'json'
require 'logger'
require 'fileutils'
require 'logger'
require 'aws-sdk-iam'
require 'aws-sdk-eks'
require 'kubeclient'
require 'rack'
require 'rack/server'
require 'prometheus/client'
require 'prometheus/middleware/collector'
require 'prometheus/middleware/exporter'

require 'cloudsap/version'
require 'cloudsap/cli'
require 'cloudsap/common'
require 'cloudsap/csa'
require 'cloudsap/metrics'
require 'cloudsap/watcher'

module Cloudsap
  PROGRAM_NAME = 'cloudsap'
  API_GROUP    = 'k8s.groundstate.io'
  API_VERSION  = 'v1alpha1'
end

include Cloudsap
