# frozen_string_literal: true

module ExternalApis

  class RorService < BaseService

    mattr_accessor :heartbeat_path
    mattr_accessor :search_path

    class << self

      def setup
        yield self
      end

      # Ping the ROR API to determine if it is online
      def ping
        resp = http_get(uri: "#{base_url}#{heartbeat_path}")
        resp.is_a?(Net::HTTPSuccess)
      end

      # Search the ROR API for the given string. This will search name, acronyms,
      # aliases, etc.
      # @return an Array of Hashes:
      # {
      #   id: 'https://ror.org/12345', name: 'Sample University'
      # }
      # The ROR limit appears to be 40 results (even with paging :/)
      def search(name:)
        return [] unless name.present?
        return local_org_search(name: name) unless ping

        results = process_pages(name: name, json: ror_name_search(name: name))
        resort(array: results, name: name)

      # If a JSON parse error occurs then return results of a local table search
      rescue JSON::ParserError => e
        log_error(method: "search", error: e)
        local_org_search(name: name)
      end

      private

      # If a name is present do a LIKE search against the Org name or abbreviation
      # otherwise return all Orgs (except is_other)
      # Thiss is the fallback method used when ROR is offline
      def local_org_search(name:)
        return Org.where(is_other: false).order(:name) unless name.present?

        term = "%#{name.downcase}%"
        Org.where(is_other: false)
           .where("LOWER(name) LIKE ? OR LOWER(abbreviation) LIKE ?", term, term)
           .order(:name)
      end

      # Queries the ROR API for the sepcified name and page
      def ror_name_search(name:, page: 1)
        return [] unless name.present?

        resp = http_get(uri: "#{base_url}#{search_path}?query=#{name}&page=#{page}")
        unless resp.is_a?(Net::HTTPSuccess)
          handle_http_failure(method: "search", http_response: resp)
          return []
        end

        JSON.parse(resp.body)
      end

      # Recursive method that can handle multiple ROR result pages if necessary
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      # rubocop:disable Metrics/CyclomaticComplexity
      def process_pages(name:, json:)
        return [] if json.blank?

        results = parse_ror_results(json: json)
        num_of_results = json.fetch("number_of_results", 1).to_i

        # Determine if there are multiple pages of results
        pages = (num_of_results / max_results_per_page.to_f).to_f.ceil
        return results unless pages > 1

        # Gather the results from the additional page (only up to the max)
        (2..(pages > max_pages ? max_pages : pages)).each do |page|
          json = ror_name_search(name: name, page: page)
          results += parse_ror_results(json: json)
        end
        results || []

      # If we encounter a JSON parse error on subsequent page requests then just
      # return what we have so far
      rescue JSON::ParserError => e
        log_error(method: "search", error: e)
        results || []
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
      # rubocop:enable Metrics/CyclomaticComplexity

      # Convert the JSON items into a hash of: { id: "ROR URL", name: "Org Name" }
      def parse_ror_results(json:)
        results = []
        return results unless json.present? && json.fetch("items", []).any?

        json["items"].each do |item|
          next unless item["id"].present? && item["name"].present?

          results << { id: item["id"], name: org_name(item: item) }
        end
        results
      end

      # Org names are not unique, so include the Org URL if available or
      # the country. For example:
      #    "Example College (example.edu)"
      #    "Example College (Brazil)"
      #
      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/CyclomaticComplexity
      def org_name(item:)
        return "" unless item.present? && item["name"].present?

        country = item.fetch("country", {}).fetch("country_name", "")
        website = item.fetch("links", []).first
        domain_regex = %r{^(?:http://|www\.|https://)([^/]+)}
        website = website.scan(domain_regex).last.first if website.present?
        # If no website or country then just return the name
        return item["name"] unless website.present? || country.present?

        # Otherwise return the contextualized name
        "#{item['name']} (#{website || country})"
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/CyclomaticComplexity

      # Resorts the results returned from ROR so that any exact matches
      # appear at the top of the list. For example a search for `Example`:
      #     - Example College
      #     - Example University
      #     - University of Example
      #     - Universidade de Examplar
      #     - Another College that ROR has a matching alias for
      #
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def resort(array:, name:)
        at_start = []
        within = []
        others = []

        array.each do |item|
          item_name = item[:name].downcase

          if item_name.start_with?(name.downcase)
            at_start << item
          elsif item_name.include?(name.downcase)
            within << item
          else
            others << item
          end
        end

        # Sort the within array by the location of the name within the string
        within = within.sort do |a, b|
          first = a[:name].downcase.index(name.downcase)
          second = b[:name].downcase.index(name.downcase)
          first <=> second
        end

        at_start.sort { |a, b| a[:name] <=> b[:name] } +
          within +
          others.sort { |a, b| a[:name] <=> b[:name] }
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    end

  end

end
