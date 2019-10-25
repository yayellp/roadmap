# locals: user

if user.respond_to?(:[])
  json.name user[:name]
  json.mbox user[:mail]
  json.contributorType user[:contributor_type]

  if user[:organization].present?
    json.organizations 1.times do
      json.name user[:organization][:name]
      if user[:organization][:id].present?
        json.identifiers 1.times do
          json.category 'HTTP-ROR'
          json.value user[:organization][:id]
        end
      end
    end
  end

  if user[:id].present?
    if user[:contributor_type] == 'primary_contact'
      json.contactIds 1.times do
        json.category 'HTTP-ORCID'
        json.value user[:id]
      end
    else
      json.staffIds 1.times do
        json.category 'HTTP-ORCID'
        json.value user[:id]
      end
    end
  end
end
