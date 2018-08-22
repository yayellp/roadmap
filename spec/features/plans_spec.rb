require "rails_helper"

RSpec.describe "Plans", type: :feature do

  before do
    @default_template = create(:template, :default, :published)
    @org          = create(:org)
    @research_org = create(:org, :organisation, :research_institute,
                           templates: 1)
    @funding_org  = create(:org, :funder, templates: 1)
    @template     = create(:template, org: @org)
    @user         = create(:user, org: @org)
  end

  context "New Plan" do

    before do
      sign_in(@user)
    end

    scenario "User creates a new Plan", :js do

      # Action
      click_link "Create plan"
      fill_in :plan_title, with: "My test plan"
      fill_in :plan_org_name, with: @research_org.name

      find('#suggestion-2-0').click
      fill_in :plan_funder_name, with: @funding_org.name
      find('#suggestion-3-0').click
      click_button "Create plan"

      # Expectations
      expect(@user.plans).to be_one
      @plan = Plan.last
      expect(current_path).to eql(plan_path(@plan))

      ##
      # User updates plan content...

      # Action
      expect(page).to have_css("input[type=text][value='#{@plan.title}']")

      within "#edit_plan_#{@plan.id}" do
        fill_in "Grant number", with: "1234"
        fill_in "Project abstract", with: "Plan abstract..."
        fill_in "ID", with: "ABCDEF"
        fill_in "ORCID iD", with: "My ORCID"
        fill_in "Phone", with: "07787 000 0000"
        click_button "Submit"
      end

      # Reload the plan to get the latest from memory
      @plan.reload

      expect(current_path).to eql(overview_plan_path(@plan))
      expect(@plan.title).to eql("My test plan")
      expect(@plan.funder_name).to eql(@funding_org.name)
      expect(@plan.grant_number).to eql("1234")
      expect(@plan.description).to eql("Plan abstract...")
      expect(@plan.identifier).to eql("ABCDEF")
      name = [@user.firstname, @user.surname].join(" ")
      expect(@plan.principal_investigator).to eql(name)
      expect(@plan.principal_investigator_identifier).to eql("My ORCID")
      expect(@plan.principal_investigator_email).to eql(@user.email)
      expect(@plan.principal_investigator_phone).to eql("07787 000 0000")
    end
  end


  context "Share Plan" do

    before do
      @plan_title = "Test plan"
      @plan = create(:plan, title: @plan_title)
      @plan.assign_creator(@user);
      @plan.reload
      sign_in(@user)
    end

    scenario "User shares a Plan", :js do

      # Action
      click_link @plan_title

      expect(current_path).to eql(plan_path(@plan))

      # Action
      click_link "Share"
      expect(current_path).to eql(share_plan_path(@plan))

      # Action
      collobarator_email = "dummy-readonly@dummymail.com"
      fill_in "Email", with: collobarator_email
      choose "role_access_level_1"
      click_button "Submit"

      notice_text = "Notice: Invitation to #{collobarator_email} issued successfully."
      expect(page).to have_text(notice_text)

      within(:xpath, "//table[@id='collaborator-table']/tbody") do

        all("tr").each { |tr|
          # Exclude row with user in collaborator table
          unless(tr.find(:xpath, "./td[1]").text.eql? @user.email)
            expect(tr.find(:xpath, "./td[1]")).to have_text(collobarator_email)
            expect(tr.find(:xpath, "./td[2]")).to have_select "role[access_level]", selected: "Read only"
            expect(tr.find(:xpath, "./td[3]")).to have_link "Remove"
          end
        }

      end
    end
  end

end
