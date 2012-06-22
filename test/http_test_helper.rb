require "cgi"
require "nokogiri"
require "json"
require "net/http"

require "lib/api"

#
# Helpers for writing integration tests which make HTTP requests to the servers being tested.
# TODO(philc): We may want to use rest_client throughout instead of Ruby's Net::HTTP library.
#
module HttpTestHelper
  attr_accessor :last_response
  attr_accessor :last_request
  # You can set this to be a Hash, and these HTTP headers will be added to all requests.
  attr_accessor :headers_for_request

  # Define this method to return the URL of the HTTP server to talk to, e.g. "http://dev.corp.ooyala.com:3000"
  def server() raise "You need to define a server() method." end

  def dom_response()
    @dom_response ||= Nokogiri::HTML(last_response.body)
  end

  def json_response
    @json_response = JSON.parse(last_response.body)
  end

  def assert_status(status_code, helpful_message = last_response.body)
    assert_equal(status_code.to_i, last_response.code.to_i, helpful_message)
  end

  def assert_content_include?(string)
    assert_block("Failed: content did not include the string: #{string}") { content_include?(string) }
  end

  def assert_content_not_include?(string)
    assert_block("Failed: should not have included this string but it did: #{string}") do
      !content_include?(string)
    end
  end

  def content_include?(string)
    raise "No request was made yet, or no response was returned" unless last_response
    last_response.body.include?(string)
  end

  # Prints out an error message and exits the program (to avoid running subsequent tests which are just
  # going to fail) if the server is not reachable.
  def ensure_reachable!(server_url, server_display_name)
    unless server_reachable?(server_url)
      puts "FAIL: Unable to connect to #{server_display_name} at #{server_url} "
      exit 1
    end
  end

  # True if the server is reachable. Fails if the server can't be contacted within 2 seconds.
  def server_reachable?(server_url)
    uri = URI.parse(server_url)
    request = Net::HTTP.new(uri.host, uri.port)
    request.read_timeout = 2
    response = nil
    begin
      response = request.request(create_request(server_url, :get))
    rescue StandardError, Timeout::Error => e
    end
    !response.nil? && response.code.to_i >= 200 && response.code.to_i < 500
  end

  [:delete, :get, :post, :put, :patch].each do |http_method|
    define_method(http_method) do |url, params = {}, request_body = nil|
      perform_request(url, http_method, params, request_body)
    end
    define_method(:"#{http_method}_with_auth") do |url, api_secret, params = {}, request_body = nil|
      raise "Authenticated requests must have api_key in the params." unless params.include? :api_key
      params[:timestamp] ||= Time.now.to_i
      signature = Api.generate_signature(http_method, url, params, api_secret)
      perform_request(url, http_method, params.merge(:signature => signature), request_body)
    end
  end

  # Used by perform_request. This can be overridden by integration tests to append things to the request,
  # like adding a login cookie.
  def create_request(url, http_method, params = {}, request_body = nil)
    uri = URI.parse(url)
    HttpTestHelper::populate_uri_with_querystring(uri, params)
    request = case http_method
    when :delete then Net::HTTP::Delete.new(uri.request_uri)
    when :get then Net::HTTP::Get.new(uri.request_uri)
    when :post then Net::HTTP::Post.new(uri.request_uri)
    when :put then Net::HTTP::Put.new(uri.request_uri)
    when :patch then Net::HTTP::Patch.new(uri.request_uri)
    end
    request.body = request_body if request_body
    headers_for_request.each { |key, value| request.add_field(key, value) } if headers_for_request
    request
  end

  def perform_request(url, http_method, params = {}, request_body = nil)
    self.last_response = nil
    url = self.server + url
    uri = URI.parse(url)
    self.last_request = create_request(url, http_method, params, request_body)
    response = Net::HTTP.new(uri.host, uri.port).request(self.last_request) rescue nil
    raise "Unable to connect to #{self.server}" if response.nil?
    self.last_response = response
  end

  def self.populate_uri_with_querystring(uri, query_string_hash)
    return if query_string_hash.nil? || query_string_hash == ""
    key_values = query_string_hash.map { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
    uri.query = uri.query.to_s.empty? ? key_values : "&" + key_values # uri.query can be nil
  end

  # This is intended to provide similar functionality to the Rails assert_select helper.
  # With no additional options, "assert_select('my_selector')" just ensures there's an element matching the
  # given selector, assuming the response is structured like XML.
  def assert_select(css_selector, options = {})
    raise "You're trying to assert_select when there hasn't been a response yet." unless dom_response
    assert_block("There were no elements matching #{css_selector}") do
      !dom_response.css(css_selector).empty?
    end
  end
end
