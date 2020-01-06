# frozen_string_literal: true

ExternalApis::RorService.setup do |config|
  config.base_url = "https://api.ror.org/"
  config.heartbeat_path = "heartbeat"
  config.search_path = "organizations"
  config.max_pages = 5
  config.max_results_per_page = 20
end
