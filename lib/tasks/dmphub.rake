# One off tasks for pushing histroical plans to the DMPHub
namespace :dmphub do

  desc "Gather all NSF templates and push them to the DMPHub"
  task :register_funder, [:funder_abbreviation] => :environment do |t, args|
    if args[:funder_abbreviation].present?
      org = Org.where(abbreviation: args[:funder_abbreviation]).first
      return 'No NSF org found!' unless org.present?

      template_ids = Template.where(org_id: org.id)
      return 'No NSF templates found!' unless template_ids.any?

      register_plans(template_ids: template_ids)
    else
      p 'You must specify a funder abbreviation! e.g. `rake dmphub:register_funder[nsf]`'
    end
  end

  def register_plans(template_ids:)
    return nil unless template_ids.present? && template_ids.any?

    hub = Dmphub::RegistrationService.new
    Plan.where(template_id: template_ids, doi: nil)
        .where.not(visibility: 2).each do |plan|
      next if plan.title.downcase.include?('test')

      begin
        payload = Dmphub::ConversionService.plan_to_rda_json(plan: plan)
        p "Unable to generate RDA JSON for plan #{plan.id}" if payload.empty?
        resp = hub.register(dmp: payload)

p resp

        p "Unable to register plan #{plan.id}: #{resp[:errors].flatten.join(', ')}" if resp[:errors].any?
        plan.update(doi: resp[:doi]) unless resp[:errors].any?
      rescue StandardError => se
        p se.message
        p se.backtrace
        next
      end
    end
  end

end
