# frozen_string_literal: true

module Dmphub

  # Service that sends DMP data to the DMPHub system and receives a DOI
  class ConversionService

    class << self
      def plan_to_rda_json(plan:)
        return {} unless plan.present? && plan.is_a?(Plan)

        @ror_scheme = IdentifierScheme.where(name: 'ror').first
        @orcid_scheme = IdentifierScheme.where(name: 'orcid').first
        @fundref_scheme = IdentifierScheme.where(name: 'fundref').first

        @plan = plan
        contact = plan_contact
        language = @plan.owner&.language || Language.default

        @plan_info = {
          landing_page_uri: Rails.application.routes.url_helpers.plan_url(@plan),
          download_uri: "#{Rails.application.routes.url_helpers.plan_export_url(@plan)}.pdf",
          ethical_issues: "unknown",
          ethics: ethics,
          language: language.abbreviation || 'en',
          contact: contact,
          staff: dm_staff(contact: contact),
          dataset: dataset,
          cost: costs,
          funding: funding
        }
        ActionController::Base.new.render_to_string template: '/dmphub/plan',
                                                    locals: { plan: @plan, plan_info: @plan_info }
      end

      private

      def user_to_hash(user:)
        return {} unless user.present? && user.is_a?(User)

        # For some reason user.user_identifiers always returns the last identifier
        # regardless of our identifier_scheme criteria. Rails has a nasty way of
        # just returning `Model.all` when a scope finds no records :/
        orcid = UserIdentifier.where(user_id: user.id, identifier_scheme: @orcid_scheme).first
        #orcid = user.user_identifiers(identifier_scheme: @orcid_scheme).first if @orcid_scheme.present?

        ror = user.org.org_identifiers.where(identifier_scheme: @ror_scheme).first if @ror_scheme.present?

        ret = {
          uid: user.id,
          name: user.name(false),
          mail: user.email,
          id: orcid&.identifier
        }
        ret[:organization] = { name: user.org.name, id: ror&.identifier } unless user.org.is_other?
        ret
      end

      def plan_contact
        if @plan.data_contact.present?
          user = User.where(email: @plan.data_contact_email).first
          # If the data contact is a user in our system, use that info
          hash = user_to_hash(user: user) if user.present?

          # Otherwise use whatever they typed
          hash = { name: @plan.data_contact, mail: @plan.data_contact_email } unless hash.present?
        else
          # If no data contact was defined use the owner
          owner = @plan.owner
          owner = @plan.roles.editor.not_creator.first&.user unless owner.present?
          hash = user_to_hash(user: owner) if owner.present?
        end
        return {} unless hash.present?
        hash[:contributor_type] = 'primary_contact'
        hash
      end

      def dm_staff(contact:)
        authors = @plan.roles.editor.where.not(user_id: contact[:uid]).map do |role|
          hash = user_to_hash(user: role.user)
          hash[:contributor_type] = 'author'
          hash
        end
        return authors unless @plan.principal_investigator.present?

        authors << {
          name: @plan.principal_investigator,
          mail: @plan.principal_investigator_email,
          contributor_type: 'principal_investigator',
          id: @plan.principal_investigator_identifier
        }
        authors
      end

      def thematic_answers(theme:)
        answers = @plan.answers.select { |a| a.question.themes.pluck(:id).include?(theme.id) }
        return {} if answers.empty?

        { desc: answers.map(&:text).join('\\r\\n') }
      end

      def ethics
        thematic_answers(theme: Theme.find_by(title: "Ethics & privacy"))
      end

      def dataset
        hash = thematic_answers(theme: Theme.find_by(title: "Data description"))
        hash[:title] = "Dataset for: #{@plan.title}" unless hash.empty?
        hash[:preservation_statement] = preservation
        hash[:data_quality_assurance] = data_quality
        hash
      end

      def costs
        thematic_answers(theme: Theme.find_by(title: "Budget"))
      end

      def preservation
        thematic_answers(theme: Theme.find_by(title: "Preservation"))
      end

      def data_quality
        thematic_answers(theme: Theme.find_by(title: "Data collection"))
      end

      def funding
        return {} unless @plan.template.org.funder?

        fundref = @plan.template.org.org_identifiers.where(identifier_scheme: @fundref_scheme).first
        {
          name: @plan.template.org.name,
          id: fundref&.identifier
        }
      end

    end

  end

end
