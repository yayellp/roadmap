# frozen_string_literal: true

require 'webdrivers/chromedriver'
require_relative "helpers/capybara_helper"
require_relative "helpers/sessions_helper"
require_relative "helpers/tiny_mce_helper"
require_relative "helpers/combobox_helper"

Capybara.default_driver = :rack_test

# Cache for one hour
Webdrivers.cache_time = 3600
# This is a customisation of the default :selenium_chrome_headless config in:
# https://github.com/teamcapybara/capybara/blob/master/lib/capybara.rb
#
# This adds the --no-sandbox flag to fix TravisCI as described here:
# https://docs.travis-ci.com/user/chrome#sandboxing
Capybara.javascript_driver = :capybara_webmock_chrome_headless

RSpec.configure do |config|

  config.before(:each, type: :feature, js: false) do
    Capybara.use_default_driver
  end

  config.before(:each, type: :feature, js: true) do
    Capybara.current_driver = :capybara_webmock_chrome_headless
  end

end

Capybara.configure do |config|
  config.default_max_wait_time = 5 # seconds
  config.server                = :webrick
  config.raise_server_errors   = true
end

RSpec.configure do |config|
  config.include(CapybaraHelper, type: :feature)
  config.include(SessionsHelper, type: :feature)
  config.include(TinyMceHelper,  type: :feature)
  config.include(ComboboxHelper, type: :feature)
end
