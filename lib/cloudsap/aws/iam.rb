# frozen_string_literal: true

module Cloudsap
  module Aws
    class IamRoleError < StandardError; end

    class IamRole
      include Common

      attr_reader :csa, :object, :sa_name, :sa_namespace, :client

      def self.irsa_template
        File.read("#{Cloudsap::Common.assets}/irsa_policy_template.erb")
      end

      def self.irsa(name, namespace)
        csa = {
          object: {
            metadata: {
              name: name,
              namespace: namespace
            },
            spec: {
              rolePolicyAttachments: [],
              rolePolicyTemplate: irsa_template,
              policyTemplateValues: {
                account_id: Cloudsap::Common.account_id,
                cluster_name: Cloudsap::Common.cluster_name
              }
            }
          },
          status: {}
        }
        new(RecursiveOpenStruct.new(csa))
      end

      def self.load(csa)
        new(csa)
      end

      def initialize(csa)
        @csa          = csa
        @object       = csa.object.to_h
        @sa_name      = object[:metadata][:name]
        @sa_namespace = object[:metadata][:namespace]
        @client       = iam_client
      end

      def name
        @name ||= "#{cluster_name}-sa-#{sa_namespace}-#{sa_name}"
      end

      def arn
        @arn ||= get_role.to_h[:role][:arn]
      end

      def description
        "IAM Role for ServiceAccount #{sa_namespace}/#{sa_name}"
      end

      def apply
        resources = fetch_resources

        return resources if digest(composite(resources)) == status[:digest]

        if (resources = create_resources(resources))
          @arn = resources[:role][:arn]
          update_status(resources)
          logger.info("APPLY, #{self.class}: #{name}")
        else
          logger.error("ERROR, #{self.class}: #{name}")
        end
      rescue StandardError => e
        log_exception(e)
        show_backtrace(e)
        csa.metrics.error
        false
      end

      def delete
        resources = fetch_resources
        delete_policy_attachments(resources)
        delete_role_policy
        delete_role
        logger.info("DELETE, #{self.class}: #{name}")
      rescue StandardError => e
        log_exception(e)
        show_backtrace(e)
        csa.metrics.error
        false
      end

      def status
        csa.status[:iamRole] || {}
      end

      def policy_template_values
        spec[:policyTemplateValues] || {}
      end

      def policy_template
        spec[:rolePolicyTemplate] || ''
      end

      def policy_attachments
        spec[:rolePolicyAttachments] || []
      end

      def policy
        @policy ||= generate_role_policy || ''
      end

      private

      def composite(resources)
        resources = resources.clone
        resources[:attached_policies] = policy_attachments
        resources[:policy_document] = Addressable::URI.encode_component(policy)
        resources
      end

      def spec
        csa.object[:spec] || {}
      end

      def fetch_resources
        %i[
          get_role
          get_role_policy
          list_attached_role_policies
        ].each_with_object({}) do |meth, memo|
          data = send(meth).to_h
          memo.merge!(data)
        end
      end

      def create_resources(resources)
        create_role
        put_role_policy
        update_policy_attachments(resources)
        fetch_resources
      end

      def update_policy_attachments(resources)
        current  = resources[:attached_policies]
        assigned = policy_attachments
        removals = current - assigned
        removals.each { |arn| detach_role_policy(arn) }
        assigned.each { |arn| attach_role_policy(arn) }
      end

      def delete_policy_attachments(resources)
        current = resources[:attached_policies]
        current.each { |arn| detach_role_policy(arn) }
      end

      def digest(data)
        Digest::SHA256.base64digest(data.to_json)
      end

      def update_status(resources)
        patch = {
          name: resources[:role][:role_name],
          digest: digest(resources)
        }
        csa.status = { status: { iamRole: patch } }
      end

      ###############################################################
      # GENERATORS
      ###############################################################

      def generate_assume_role_policy_document
        {
          'Version' => '2012-10-17',
          'Statement' => [
            {
              'Effect' => 'Allow',
              'Principal' => {
                'Federated' => "arn:aws:iam::#{account_id}:oidc-provider/#{oidc_issuer}"
              },
              'Action' => 'sts:AssumeRoleWithWebIdentity',
              'Condition' => {
                'StringEquals' => {
                  "#{oidc_issuer}:sub" => "system:serviceaccount:#{sa_namespace}:#{sa_name}"
                }
              }
            }
          ]
        }.to_json
      end

      def generate_role_policy
        ERB.new(policy_template).result_with_hash(policy_template_values)
      rescue NameError => e
        raise IamRoleError, "ERB cannot render policy template: #{e.message}"
      end

      ###############################################################
      # GETTERS
      ###############################################################

      # rubocop:disable Naming/AccessorMethodName
      def get_role
        default = { role: {} }
        resp = client.get_role({ role_name: name })
        return resp if resp.successful?

        raise IamRoleError, "Error getting IAM Role: #{resp.error}"
      rescue ::Aws::IAM::Errors::NoSuchEntity => e
        log_exception(e, :debug)
        default
      end

      def get_role_policy
        default = { policy_document: '' }
        resp = client.get_role_policy({ role_name: name, policy_name: name })
        return resp if resp.successful?

        raise IamRoleError, "Error getting IAM Role Policy: #{resp.error}"
      rescue ::Aws::IAM::Errors::NoSuchEntity => e
        log_exception(e, :debug)
        default
      end
      # rubocop:enable Naming/AccessorMethodName

      def list_attached_role_policies
        default = { attached_policies: [] }
        resp = client.list_attached_role_policies({ role_name: name })

        if resp.successful?
          return resp[:attached_policies].each_with_object(default) do |e, memo|
            memo[:attached_policies] << e[:policy_arn]
          end
        end

        raise IamRoleError, "Error listing IAM Role Policy Attachments: #{resp.error}"
      rescue ::Aws::IAM::Errors::NoSuchEntity => e
        log_exception(e, :debug)
        default
      end

      ###############################################################
      # SETTERS
      ###############################################################

      def delete_role
        resp = client.delete_role({
                                    role_name: name
                                  })
        return resp if resp.successful?

        raise IamRoleError, "Error deleting IAM Role: #{resp.error}"
      rescue ::Aws::IAM::Errors::NoSuchEntity => e
        log_exception(e, :debug)
      end

      # rubocop:disable Layout/LineLength
      def create_role
        resp = client.create_role({
                                    role_name: name,
                                    description: description,
                                    assume_role_policy_document: generate_assume_role_policy_document
                                  })
        return resp if resp.successful?

        raise IamRoleError, "Error creating IAM Role: #{resp.error}"
      rescue ::Aws::IAM::Errors::EntityAlreadyExists => e
        log_exception(e, :debug)
        update_role
        update_assume_role_policy
      end

      def update_role
        resp = client.update_role({
                                    role_name: name,
                                    description: description
                                  })
        return resp if resp.successful?

        raise IamRoleError, "Error updating IAM Role: #{resp.error}"
      end

      def update_assume_role_policy
        resp = client.update_assume_role_policy({
                                                  role_name: name,
                                                  policy_document: generate_assume_role_policy_document
                                                })
        return resp if resp.successful?

        raise IamRoleError, "Error updating IAM Assume Role Policy: #{resp.error}"
      end
      # rubocop:enable Layout/LineLength

      def put_role_policy
        return if policy.empty?

        resp = client.put_role_policy({
                                        role_name: name,
                                        policy_name: name,
                                        policy_document: policy
                                      })
        return resp if resp.successful?

        raise IamRoleError, "Error putting IAM Role Policy: #{resp.error}"
      end

      def delete_role_policy
        resp = client.delete_role_policy({
                                           role_name: name,
                                           policy_name: name
                                         })
        return resp if resp.successful?

        raise IamRoleError, "Error putting IAM Role Policy: #{resp.error}"
      rescue ::Aws::IAM::Errors::NoSuchEntity => e
        log_exception(e, :debug)
      end

      def attach_role_policy(arn)
        resp = client.attach_role_policy({
                                           role_name: name,
                                           policy_arn: arn
                                         })
        return resp if resp.successful?

        raise IamRoleError, "Error attaching IAM Role Policy: #{resp.error}"
      end

      def detach_role_policy(arn)
        resp = client.detach_role_policy({
                                           role_name: name,
                                           policy_arn: arn
                                         })
        return resp if resp.successful?

        raise IamRoleError, "Error detaching IAM Role Policy: #{resp.error}"
      rescue ::Aws::IAM::Errors::NoSuchEntity => e
        log_exception(e, :debug)
      end
    end
  end
end
