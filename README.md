# Cloudsap

---

![Build Status](https://github.com/dayglojesus/cloudsap/workflows/Build%20Status/badge.svg)
[![GitHub release](https://img.shields.io/github/release/dayglojesus/cloudsap.svg)](https://github.com/dayglojesus/cloudsap/releases)
![Docker Pulls](https://img.shields.io/docker/pulls/dayglojesus/cloudsap.svg)

Kubernetes CRD + Controller for creating and managing AWS IAM Roles for Service Accounts in [EKS](https://aws.amazon.com/eks/).

> ⚠️ Cloudsap is functional, but still **experimental**.

## Overview

---

**Cloudsap lets you manage AWS IRSA using a single CRD.**

**[AWS IAM Roles for ServiceAccounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)** presents the most secure method for granting AWS API privileges to a Pod in EKS, but coordinating the management of the resources required to construct this relation is awkward.

Cloudsap alleviates the overhead of this setup, by managing the lifecycle of paired AWS IAM Roles and Kubernetes ServiceAccounts, under a **[single CRD](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/)**.

## How does it work?

---

This is a contrived example but outlines Cloudsap's basic features:

* a single CRD
  - creates an appropriate IAM Role in AWS
  - creates a linked `ServiceAccount` in Kubernetes (EKS)
* supports inline IAM Role Policy templating
  - use Ruby ERB templating
* supports existing IAM Policy attachment

```
apiVersion: k8s.groundstate.io/v1alpha1
kind: CloudServiceAccount
metadata:
  name: demo
spec:
  policyTemplateValues:
    account: 000000000000
    bucket: arn:aws:s3:::buckit
  rolePolicyTemplate: |-
    {
      "Version": "2012-10-17",
      "Id": "S3-Account-Permissions for <%= account %>",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "s3:Get*",
            "s3:List*",
            "s3:Describe*"
          ],
          "Resource": "<%= bucket %>"
        }
      ]
    }
  rolePolicyAttachments:
    - "arn:aws:iam::aws:policy/AmazonDocDBReadOnlyAccess"
    - "arn:aws:iam::aws:policy/AlexaForBusinessReadOnlyAccess"
    - "arn:aws:iam::aws:policy/AmazonCloudDirectoryReadOnlyAccess"
    - "arn:aws:iam::aws:policy/AmazonConnectReadOnlyAccess"
```

## Requirements

* credentials to access AWS API
  - For development purposes, you can use your AWS CLI credentials, but you should use an IRSA for actual deployments. More on this in the [Deploying to a Cluster](#Deploying-to-a-Cluster) ...
* permission to manage IAM Roles (create, update, destroy)
* permission to manage `ServiceAccounts` in Kubernetes
  - Cloudsap monitors resources of kind `CloudServiceAccount` in ALL namsepaces and therefore requires a cluster role capable of performing this duty

## Running Cloudsap

### Deploying to a Cluster

Assuming you've already created an EKS cluster and associated Identity Provider per the instructions [here](https://docs.aws.amazon.com/eks/latest/userguide/getting-started-console.html), the simplest way to setup is to us the `install` subcommand:

#### 1. Create an IAM Role for Cloudsap to use

You will need to pass **AWS credentials** ...

```
docker run --rm \
  -v ~/.aws/credentials:/root/.aws/credentials \
  dayglojesus/cloudsap:latest \
  install irsa \
  --aws-region=ca-central-1 \
  --cluster-name=my-cluster \
  --namespace=kube-system
```

If successful, you should receive:

```
Initializing ...
APPLY, Cloudsap::Aws::IamRole: mycluster-sa-kube-system-cloudsap
```

> If you receive `undefined method 'oidc' for nil:NilClass`, you did not setup your **Identity Provider** correctly. Review the [AWS EKS Getting Started documentation](https://docs.aws.amazon.com/eks/latest/userguide/getting-started-console.html).

> If you receive `unable to sign request without credentials set`, then something went wrong passing your credentials. Review your incantation and try again.

You can confirm the existence of the new IAM Role and ServiceAccount with:

`aws iam get-role --role-name my-cluster-sa-kube-system-cloudsap`

#### 2. Apply the emitted manifest

This subcommand produces a manifest for installing Cloudsap on your cluster. Piping the output through `kubectl` makes it simple to setup, but you may wish to review its contents first.

You will need AWS credentials and **Kubernetes cluster-admin rights** tp perform this operation. Make sure you're properly authenticated to your EKS cluster and your context is set properly. For assistance with this, follow the [AWS instructions](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html).

```
docker run --rm \
  dayglojesus/cloudsap:latest \
  install full \
  --aws-region=ca-central-1 \
  --cluster-name=my-cluster \
  --namespace=kube-system | kubectl apply -f -
```

### Creating CloudServiceAccounts (CSA)

`CloudServiceAccount` resources are quite simple, but there a few key concepts you should be aware of ...

#### Naming Conventions

The CSA resource manages a pair associated resource in Kubernetes and AWS on your behalf. When creating these resources, it uses the following conventions:

* AWS IAM Role: `<clustername>-sa-<.metadata.namespace>-<.metadata.name>`
* Kubernetes ServiceAccount: `<.metadata.namespace>/<.metadata.name>`

More on this in the [Deploying to a Cluster](#Deploying-to-a-Cluster) ...

#### Policy Attachments

Each CSA can decalare up to 10 IAM policy attachments using the `spec.rolePolicyAttachments` attribute.

These can be AWS Default policies or ones you've devised yourself.

#### Policy Templates

CSAs can also be used to declare inline IAM Role Policy and have facility for templating valuesusing standard [**Ruby ERB templating**](https://ruby-doc.org/stdlib-2.7.1/libdoc/erb/rdoc/ERB.html).

Tags you insert into the `spec.rolePolicyTemplate`, will (when rendered) be substituted with values in the `spec.policyTemplateValues` map.

#### Examples

See the [demo CSA in the examples directory](./examples/csa-demo-simple.yaml).

### Prometheus

Cloudsap is scrapable on port `8080` at `/metrics`:

* `cloudsap_watcher_added`: running total of CSAs added
* `cloudsap_watcher_modified`: running total of CSAs modified
* `cloudsap_watcher_deleted`: running total of CSAs deleted
* `cloudsap_watcher_error`: running total of Cloudsap errors
* `cloudsap_watcher_restart`: running total of Cloudsap restarts

## Development

**NOTE: You will require a Ruby 2.7 installation to run Cloudsap locally for development purposes.**

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dayglojesus/cloudsap.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
