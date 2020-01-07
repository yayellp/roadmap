# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExternalApis::RorService do

  describe "#ping" do
    before(:each) do
      @headers = described_class.headers
      @heartbeat = URI("#{described_class.base_url}#{described_class.heartbeat_path}")
    end
    it "returns true if an HTTP 200 is returned" do
      stub_request(:get, @heartbeat).with(headers: @headers)
                                    .to_return(status: 200, body: "", headers: {})
      expect(described_class.ping).to eql(true)
    end
    it "returns false if an HTTP 200 is NOT returned" do
      stub_request(:get, @heartbeat).with(headers: @headers)
                                    .to_return(status: 404, body: "", headers: {})
      expect(described_class.ping).to eql(false)
    end
  end

  describe "#search" do
    before(:each) do
      @headers = described_class.headers
      @search = URI("#{described_class.base_url}#{described_class.search_path}")
      @heartbeat = URI("#{described_class.base_url}#{described_class.heartbeat_path}")
      stub_request(:get, @heartbeat).with(headers: @headers).to_return(status: 200)
    end

    it "returns an empty array if name is blank" do
      expect(described_class.search(name: nil)).to eql([])
    end

    it "ROR is not responding to a ping so the service should call local_org_search" do
      stub_request(:get, @heartbeat).with(headers: @headers)
                                    .to_return(status: 404, body: "", headers: {})
      name = Faker::Lorem.word
      described_class.expects(:local_org_search).with(name: name).at_least(1)
      described_class.search(name: name)
    end

    context "ROR did not return a 200 status" do
      before(:each) do
        @name = Faker::Lorem.word
        uri = "#{@search}?page=1&query=#{@name}"
        stub_request(:get, uri).with(headers: @headers)
          .to_return(status: 404, body: "", headers: {})
      end
      it "returns an empty array" do
        expect(described_class.search(name: @name)).to eql([])
      end
      it "logs the response as an error" do
        described_class.expects(:handle_http_failure).at_least(1)
        described_class.search(name: @name)
      end
    end

    it "returns an empty string if ROR found no matches" do
      results = {
        "number_of_results": 0,
        "time_taken": 23,
        "items": [],
        "meta": { "types": [], "countries"=>[] }
      }
      name = Faker::Lorem.word
      uri = "#{@search}?page=1&query=#{name}"
      stub_request(:get, uri).with(headers: @headers)
        .to_return(status: 200, body: results.to_json, headers: {})
      expect(described_class.search(name: name)).to eql([])
    end

    context "Successful response from API" do
      before(:each) do
        results = {
          "number_of_results": 2,
          "time_taken": 5,
          "items": [
            {
              "id": "https://ror.org/1234567890",
              "name": "Example University",
              "types": ["Education"],
              "links": ["http://example.edu/"],
              "aliases": ["Example"],
              "acronyms": ["EU"],
              "status": "active",
              "country": { "country_name": "United States", "country_code": "US" },
              "external_ids": {
                "GRID": { "preferred": "grid.12345.1", "all": "grid.12345.1" }
              }
            },{
              "id": "https://ror.org/0987654321",
              "name": "Universidade de Example",
              "types": ["Education"],
              "links": [],
              "aliases": ["Example"],
              "acronyms": ["EU"],
              "status": "active",
              "country": { "country_name": "Mexico", "country_code": "MX" },
              "external_ids": {
                "GRID": { "preferred": "grid.98765.8", "all": "grid.98765.8" }
              }
            }
          ]
        }
        name = Faker::Lorem.word
        uri = "#{@search}?page=1&query=#{name}"
        stub_request(:get, uri).with(headers: @headers)
          .to_return(status: 200, body: results.to_json, headers: {})
        @orgs = described_class.search(name: name)
      end

      it "returns both results" do
        expect(@orgs.length).to eql(2)
      end

      it "includes the website in the name (if available)" do
        expected = {
          id:  "https://ror.org/1234567890",
          name: "Example University (example.edu)"
        }
        expect(@orgs.include?(expected)).to eql(true)
      end

      it "includes the country in the name (if no website is available)" do
        expected = {
          id:  "https://ror.org/0987654321",
          name: "Universidade de Example (Mexico)"
        }
        expect(@orgs.include?(expected)).to eql(true)
      end
    end
  end

  context "private methods" do
    describe "#local_org_search" do
      before(:each) do
        @org = create(:org, is_other: false)
        @org2 = create(:org, is_other: false)
        @other = create(:org, is_other: true)
      end

      it "returns all Orgs if no name is passed (except the is_other Org)" do
        rslts = described_class.send(:local_org_search, name: nil)
        expect(rslts.length).to eql(2)
        expect(rslts.include?(@org2)).to eql(true)
        expect(rslts.include?(@org)).to eql(true)
      end
      it "returns the org who's name matches the search name" do
        rslts = described_class.send(:local_org_search, name: @org.name)
        expect(rslts.length).to eql(1)
        expect(rslts.first).to eql(@org)
      end
      it "returns the org who's abbreviation matches the search name" do
        rslts = described_class.send(:local_org_search, name: @org.abbreviation)
        expect(rslts.length).to eql(1)
        expect(rslts.first).to eql(@org)
      end
      it "it does not return the is_other Org even if it matches the search name" do
        rslts = described_class.send(:local_org_search, name: @other.name)
        expect(rslts.empty?).to eql(true)
      end
      it "it returns an empty array if no Orgs matched the search name" do
        rslts = described_class.send(:local_org_search, name: "3784658y38tyq349g")
        expect(rslts.empty?).to eql(true)
      end
      it "ignores case sensitivity" do
        rslts = described_class.send(:local_org_search, name: @org.name.upcase)
        expect(rslts.length).to eql(1)
        expect(rslts.first).to eql(@org)
      end
    end
  end

  describe "#ror_name_search" do
    before(:each) do
      @results = {
        "number_of_results": 1,
        "time_taken": 5,
        "items": [{
          "id": Faker::Internet.url,
          "name": Faker::Lorem.word,
          "country": { "country_name": Faker::Lorem.word }
        }]
      }
      @name = Faker::Lorem.word
      @headers = described_class.headers
      search = URI("#{described_class.base_url}#{described_class.search_path}")
      @uri = "#{search}?page=1&query=#{@name}"
    end

    it "returns an empty array if name is blank" do
      expect(described_class.send(:ror_name_search, name: nil)).to eql([])
    end
    it "calls the handle_http_failure method if a non 200 response is received" do
      stub_request(:get, @uri).with(headers: @headers)
        .to_return(status: 403, body: "", headers: {})
      described_class.expects(:handle_http_failure).at_least(1)
      expect(described_class.send(:ror_name_search, name: @name)).to eql([])
    end
    it "returns the response body as JSON" do
      stub_request(:get, @uri).with(headers: @headers)
        .to_return(status: 200, body: @results.to_json, headers: {})
      expect(described_class.send(:ror_name_search, name: @name)).not_to eql([])
    end
  end

  describe "#process_pages" do
    before(:each) do
      described_class.max_pages = 2
      described_class.max_results_per_page = 5

      @search = URI("#{described_class.base_url}#{described_class.search_path}")
      @name = Faker::Lorem.word
      @headers = described_class.headers
    end

    it "returns an empty array if json is blank" do
      expect(described_class.send(:process_pages, name: @name, json: nil).length).to eql(0)
    end
    it "properly manages results with only one page" do
      items = 4.times.map do
        {
          "id": Faker::Internet.unique.url,
          "name": Faker::Lorem.word,
          "country": { "country_name": Faker::Lorem.word }
        }
      end
      results1 = { "number_of_results": 4, "items": items}

      stub_request(:get, "#{@search}?page=1&query=#{@name}").with(headers: @headers)
        .to_return(status: 200, body: results1.to_json, headers: {})

      json = JSON.parse({ "items": items, "number_of_results": 4 }.to_json)
      rslts = described_class.send(:process_pages, name: @name, json: json)

      expect(rslts.length).to eql(4)
    end
    it "properly manages results with multiple pages" do
      items = 7.times.map do
        {
          "id": Faker::Internet.unique.url,
          "name": Faker::Lorem.word,
          "country": { "country_name": Faker::Lorem.word }
        }
      end
      results1 = { "number_of_results": 7, "items": items[0..4] }
      results2 = { "number_of_results": 7, "items": items[5..6] }

      stub_request(:get, "#{@search}?page=1&query=#{@name}").with(headers: @headers)
        .to_return(status: 200, body: results1.to_json, headers: {})
      stub_request(:get, "#{@search}?page=2&query=#{@name}").with(headers: @headers)
        .to_return(status: 200, body: results2.to_json, headers: {})

      json = JSON.parse({ "items": items[0..4], "number_of_results": 7 }.to_json)
      rslts = described_class.send(:process_pages, name: @name, json: json)
      expect(rslts.length).to eql(7)
    end
    it "does not go beyond the max_pages" do
      items = 12.times.map do
        {
          "id": Faker::Internet.unique.url,
          "name": Faker::Lorem.word,
          "country": { "country_name": Faker::Lorem.word }
        }
      end
      results1 = { "number_of_results": 12, "items": items[0..4] }
      results2 = { "number_of_results": 12, "items": items[5..9] }

      stub_request(:get, "#{@search}?page=1&query=#{@name}").with(headers: @headers)
        .to_return(status: 200, body: results1.to_json, headers: {})
      stub_request(:get, "#{@search}?page=2&query=#{@name}").with(headers: @headers)
        .to_return(status: 200, body: results2.to_json, headers: {})

      json = JSON.parse({ "items": items[0..4], "number_of_results": 12 }.to_json)
      rslts = described_class.send(:process_pages, name: @name, json: json)
      expect(rslts.length).to eql(10)
    end
  end

  describe "#parse_ror_results" do
    it "returns an empty array if there are no items" do
      expect(described_class.send(:parse_ror_results, json: nil)).to eql([])
    end
    it "ignores items with no name or id" do
      json = { "items": [
        { "id": Faker::Internet.url, "name": Faker::Lorem.word },
        { "id": Faker::Internet.url },
        { "name": Faker::Lorem.word }
      ]}.to_json
      items = described_class.send(:parse_ror_results, json: JSON.parse(json))
      expect(items.length).to eql(1)
    end
    it "returns the correct number of results" do
      json = { "items": [
        { "id": Faker::Internet.url, "name": Faker::Lorem.word },
        { "id": Faker::Internet.url, "name": Faker::Lorem.word }
      ]}.to_json
      items = described_class.send(:parse_ror_results, json: JSON.parse(json))
      expect(items.length).to eql(2)
    end
  end

  describe "#org_name" do
    it "returns nil if there is no name" do
      json = { "country": { "country_name": "Nowhere" } }.to_json
      expect(described_class.send(:org_name, item: JSON.parse(json))).to eql("")
    end
    it "properly appends the website if available" do
      json = {
        "name": "Example College",
        "links": ["https://example.edu"],
        "country": { "country_name": "Nowhere" }
      }.to_json
      expected = "Example College (example.edu)"
      expect(described_class.send(:org_name, item: JSON.parse(json))).to eql(expected)
    end
    it "properly appends the country if available and no website is available" do
      json = {
        "name": "Example College",
        "country": { "country_name": "Nowhere" }
      }.to_json
      expected = "Example College (Nowhere)"
      expect(described_class.send(:org_name, item: JSON.parse(json))).to eql(expected)
    end
    it "properly handles an item with no website or country" do
      json = {
        "name": "Example College",
        "links": [],
        "country": {}
      }.to_json
      expected = "Example College"
      expect(described_class.send(:org_name, item: JSON.parse(json))).to eql(expected)
    end
  end

  describe "#resort" do
    before(:each) do
      array = [
        { id: Faker::Internet.url, name: "Foo Test" },
        { id: Faker::Internet.url, name: "Foo Bar" },
        { id: Faker::Internet.url, name: "Test Foo" },
        { id: Faker::Internet.url, name: "Foo Bar (test)" },
        { id: Faker::Internet.url, name: "Test Bar" },
        { id: Faker::Internet.url, name: "Bar Foo" }
      ]
      @results = described_class.send(:resort, array: array, name: "test")
    end

    it "places matches that start with the search word first" do
      expect(@results[0][:name]).to eql("Test Bar")
      expect(@results[1][:name]).to eql("Test Foo")
    end
    it "places matches that do not start with but contain the search word next" do
      expect(@results[2][:name]).to eql("Foo Test")
      expect(@results[3][:name]).to eql("Foo Bar (test)")
    end
    it "places matches that do not contain the search word at the end" do
      expect(@results[4][:name]).to eql("Bar Foo")
      expect(@results[5][:name]).to eql("Foo Bar")
    end
  end

end
