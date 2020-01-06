# frozen_string_literal: true

module ExternalApis

  class ExternalApiError < StandardError; end

  class BaseService

    # The following should be defined in each inheriting service's initializer.
    # For example:
    #   ExternalApis::RorService.setup do |config|
    #     config.base_url = "https://api.example.org/"
    #   end
    mattr_accessor :base_url
    mattr_accessor :max_pages
    mattr_accessor :max_results_per_page

    class << self

      # called by the inheriting service's initializer to define attributes
      def setup
        yield self
      end

      # The standard headers to be used when communicating with an external API.
      def headers
        {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Accept-Encoding": "gzip",
          "Host": "#{URI(base_url).hostname}",
          "User-Agent": "#{app_name} (#{app_email})"
        }
      end

      # Logs the results of a failed HTTP response from ROR
      def handle_http_failure(method:, http_response:)
        content = http_response.inspect
        msg = "received a #{http_response.code} response with: #{content}!"
        log_error(method: method, error: ExternalApiError.new(msg))
      end

      # Logs the specified error along with the full backtrace
      def log_error(method:, error:)
        return unless method.present? && error.present?

        Rails.logger.error "#{self.class.name}.#{method} #{error.message}"
        Rails.logger.error error.backtrace
      end

      private

      # Shortcut to the branding.yml
      def config
        Rails.configuration.branding
      end

      # Retrieves the application name from branding.yml or uses the App name
      def app_name
        config.fetch(:application, {}).fetch(:name, Rails.application.class.name)
      end

      # Retrieves the helpdesk email from branding.yml or uses the contact page url
      def app_email
        dflt = Rails.application.routes.url_helpers.contact_us_url
        config.fetch(:organisation, {}).fetch(:helpdesk_email, dflt)
      end

      # Makes a GET request to the specified uri with the additional headers.
      # Additional headers are combined with the base headers defined above.
      def http_get(uri:, additional_headers: {})
        return nil unless uri.present?

        uri = URI.parse(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.scheme == "https"
        req = Net::HTTP::Get.new(uri.request_uri)
        headers.each { |k, v| req[k] = v }
        additional_headers.each { |k, v| req[k] = v }
        http.request(req)

      rescue StandardError => se
        log_error(clazz: self.class.name, meth: uri, error: se)
        return nil
      end

    end

  end

end
