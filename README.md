# Cloudsap

![Build Status](https://github.com/dayglojesus/cloudsap/workflows/Build%20Status/badge.svg)

Kubernetes CRD + Controller for creating and managing AWS IAM Roles for Service Accounts.

> ⚠️ Cloudsap is functional, but still **experimental**. Proceed with Caution.

## Overview

**[AWS IAM Roles for ServiceAccounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)** presents the most secure method for granting AWS API privileges to a Pod in EKS, but coordinating the management of the resources required to construct this relation is awkward.

Cloudsap alleviates the overhead of this setup, by managing the lifecycle of paired AWS IAM Roles and Kubernetes ServiceAccounts, under a **[single CRD](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/)**.

## Installation

TODO: Write installation instructions here

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dayglojesus/cloudsap.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
