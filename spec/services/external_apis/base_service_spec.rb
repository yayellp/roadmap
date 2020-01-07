# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExternalApis::BaseService do
  describe "#setup" do
    before(:each) do
      described_class.setup do |config|
        config.base_url = Faker::Internet.url
        config.max_pages = Faker::Number.number(digits: 1)
        config.max_results_per_page = Faker::Number.number(digits: 2)
      end
    end

    it "sets the attributes defined in the configuration" do
      expect(described_class.base_url.present?).to eql(true)
      expect(described_class.max_pages.present?).to eql(true)
      expect(described_class.max_results_per_page.present?).to eql(true)
    end
  end

  describe "#headers" do
    before(:each) do
      @headers = described_class.headers
    end
    it "sets the Content-Type header for JSON" do
      expect(@headers[:"Content-Type"]).to eql("application/json")
    end
    it "sets the Accept header for JSON" do
      expect(@headers[:Accept]).to eql("application/json")
    end
    it "sets the User-Agent header for the default Application name and contact us url" do
      expected = "#{described_class.send(:app_name)}" \
                 " (#{described_class.send(:app_email)})"
      expect(@headers[:"User-Agent"]).to eql(expected)
    end
  end

  describe "#log_error" do
    before(:each) do
      @err = Exception.new(Faker::Lorem.sentence)
    end
    it "does not write to the log if method is undefined" do
      expect(described_class.log_error(method: nil, error: @err)).to eql(nil)
    end
    it "does not write to the log if error is undefined" do
      expect(described_class.log_error(method: Faker::Lorem.word, error: nil)).to eql(nil)
    end
    it "writes to the log" do
      Rails.logger.expects(:error).at_least(1)
      described_class.log_error(method: Faker::Lorem.word, error: @err)
    end
  end

  context "private methods" do
    context "#config" do
      it "returns the branding.yml config" do
        expected = Rails.application.config.branding
        expect(described_class.send(:config)).to eql(expected)
      end
    end
    context "#app_name" do
      it "defaults to the Rails.application.class.name" do
        Rails.configuration.branding[:application].delete(:name)
        expected = Rails.application.class.name
        expect(described_class.send(:app_name)).to eql(expected)
      end
      it "returns the application name defined in branding.yml" do
        Rails.configuration.branding[:application][:name] = "Foo"
        expect(described_class.send(:app_name)).to eql("Foo")
      end
    end
    context "#app_email" do
      it "defaults to the contact_us url" do
        Rails.configuration.branding[:organisation].delete(:helpdesk_email)
        expected = Rails.application.routes.url_helpers.contact_us_url
        expect(described_class.send(:app_email)).to eql(expected)
      end
      it "returns the help_desk email defined in branding.yml" do
        Rails.configuration.branding[:organisation][:helpdesk_email] = "Foo"
        expect(described_class.send(:app_email)).to eql("Foo")
      end
    end
    context "#http_get" do
      before(:each) do
        @uri = "http://example.org"
      end
      it "returns nil if no URI is specified" do
        expect(described_class.send(:http_get, uri: nil)).to eql(nil)
      end
      it "returns nil if an error occurs" do
        expect(described_class.send(:http_get, uri: "badurl~^(%")).to eql(nil)
      end
      it "logs an error if an error occurs" do
        Rails.logger.expects(:error).at_least(1)
        expect(described_class.send(:http_get, uri: "badurl~^(%")).to eql(nil)
      end
      it "returns an HTTP response" do
        stub_request(:get, @uri).with(headers: described_class.headers)
                                .to_return(status: 200, body: "", headers: {})
        expect(described_class.send(:http_get, uri: @uri).code).to eql("200")
      end
      it "accomodates HTTPS" do
        uri = @uri.gsub("http:", "https:")
        stub_request(:get, @uri).with(headers: described_class.headers)
                                .to_return(status: 200, body: "", headers: {})
        expect(described_class.send(:http_get, uri: @uri).code).to eql("200")
      end
      it "allows additional headers" do
        headers = described_class.headers
        word = Faker::Lorem.word
        headers["Foo"] = word
        # If the stub here works then this test passed
        stub_request(:get, @uri).with(headers: described_class.headers)
                                .to_return(status: 200, body: "", headers: {})
        resp = described_class.send(:http_get, uri: @uri,
                                    additional_headers: { "Foo": word })
        expect(resp.is_a?(Net::HTTPSuccess)).to eql(true)
      end
      it "allows base headers to be overwritten" do
        headers = described_class.headers
        word = Faker::Lorem.word
        headers["Accept"] = word
        # If the stub here works then this test passed
        stub_request(:get, @uri).with(headers: headers)
                                .to_return(status: 200, body: "", headers: {})
        resp = described_class.send(:http_get, uri: @uri,
                                    additional_headers: { "Accept": word })
        expect(resp.is_a?(Net::HTTPSuccess)).to eql(true)
      end
      it "follows redirects" do
        uri2 = "#{@uri}/redirected"
        stub_redirect(uri: @uri, redirect_to: uri2)
        stub_request(:get, uri2).with(headers: described_class.headers)
                                .to_return(status: 200, body: "", headers: {})

        resp = described_class.send(:http_get, uri: @uri)
        expect(resp.is_a?(Net::HTTPSuccess)).to eql(true)
      end
      it "does not allow more than the max number of redirects" do
        (described_class.max_redirects).times.each do |i|
          stub_redirect(uri: "#{@uri}/redirect#{i}",
                        redirect_to: "#{@uri}/redirect#{i + 1}")
        end
        final_uri = "#{@uri}/redirect#{described_class.max_redirects}"
        stub_request(:get, final_uri).with(headers: described_class.headers)
                                .to_return(status: 200, body: "", headers: {})

        resp = described_class.send(:http_get, uri: "#{@uri}/redirect0")
        expect(resp.is_a?(Net::HTTPRedirection)).to eql(true)
      end
    end
  end

  def stub_redirect(uri:, redirect_to:)
    stub_request(:get, uri).with(headers: described_class.headers)
                           .to_return(status: 301, body: "",
                                      headers: { "Location": redirect_to })
  end
end
