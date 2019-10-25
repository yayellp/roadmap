json.prettify!
json.ignore_nil!

json.dmp do
  json.title plan.title
  json.description plan.description
  json.language plan_info[:language]
  json.created plan.created_at
  json.modified plan.updated_at

  json.ethicalIssuesExist plan_info[:ethical_issues]
  json.ethicalIssuesDescription plan_info[:ethics][:desc]

  json.downloadURL plan_info[:download_uri]

  json.contact do
    json.partial! "/dmphub/user", user: plan_info[:contact]
  end

  ids = [{ category: 'URL', value: plan_info[:landing_page_uri] }]
  ids << { category: 'DOI', value: plan.doi } if plan.doi.present?

  json.dmpIds ids do |id|
    json.value id[:value]
    json.category id[:category]
  end

  json.dmStaff plan_info[:staff] do |user|
    json.partial! "/dmphub/user", user: user
  end

  json.project do
    json.title plan.title
    json.description plan.description
    # TODO: We should probably start capturing this from user input!
    json.startOn plan.created_at
    json.endOn (plan.created_at + 2.years)

    if plan_info[:funding].any?
      json.funding 1.times do
        json.funderName plan_info[:funding][:name]
        json.funderId plan_info[:funding][:id]
        json.fundingStatus "planned"
      end
    end
  end

  json.costs 1.times do
    json.title "General Costs"
    json.description plan_info[:cost][:desc]
  end

  json.datasets 1.times do
    json.personalData "unknown"
    json.sensitiveData "unknown"
    json.title plan_info[:dataset][:title]
    json.type "http://purl.org/coar/resource_type/c_ddb1"
    json.description plan_info[:dataset][:desc]

    json.dataQualityAssurance plan_info[:dataset][:data_quality_assurance].fetch(:desc, nil)
    json.preservationStatement plan_info[:dataset][:preservation_statement].fetch(:desac, nil)
  end
end
