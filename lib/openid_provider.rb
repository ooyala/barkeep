require "bundler/setup"
require "environment"
require "openid"
require "openid/extensions/ax"
require "openid/store/filesystem"

# Openid authentication provider. This Modukle is registered with sinatra if AUTHENTICATION_PROVIDERS is set
# to 'openid', so authentication routes can be hosted here.
module OpenidProvider
  OPENID_AX_EMAIL_SCHEMA = "http://axschema.org/contact/email"

  # OPENID_PROVIDERS is a string env variable. It's a comma-separated list of OpenID providers.
  OPENID_PROVIDERS_ARRAY = OPENID_PROVIDERS.split(",")

  # Construct redirect url to google openid.
  def self.get_openid_login_redirect(openid_provider_url, request, session)
    @openid_consumer ||= OpenID::Consumer.new(session,
        OpenID::Store::Filesystem.new(File.join(File.dirname(__FILE__), "/tmp/openid")))
    begin
      service = OpenID::OpenIDServiceEndpoint.from_op_endpoint_url(openid_provider_url)
      oidreq = @openid_consumer.begin_without_discovery(service, false)
    rescue OpenID::DiscoveryFailure => why
      "Could not contact #{OPENID_DISCOVERY_ENDPOINT}. #{why}"
    else
      ax_request = OpenID::AX::FetchRequest.new
      # Information we require from the OpenID provider.
      required_fields = ["http://axschema.org/contact/email"]
      required_fields.each { |field| ax_request.add(OpenID::AX::AttrInfo.new(field, nil, true)) }
      oidreq.add_extension(ax_request)
      host = "#{request.scheme}://#{request.host_with_port}"
      oidreq.redirect_url(host, "#{host}/signin/complete")
    end
  end

  # Entry point for user signin. The user will be redirected to this url to start authentication. This
  # provider is expected set session[:login_started_url] with the user's email set inside session[:email] when
  # signin is complete, or show an error if signin fails.
  def self.signin_url(request, session)
    if OPENID_PROVIDERS_ARRAY.size == 1
      get_openid_login_redirect(OPENID_PROVIDERS_ARRAY.first, request, session)
    else
      "/signin/select_openid_provider"
    end
  end

  # Routes for authentication are defined here, and will be processed by Sinatra when this module is
  # registered.
  def self.registered(app)
    # Users navigate to here from select_openid_provider.
    # - provider_id: an integer indicating which provider from OPENID_PROVIDERS_ARRAY to use for authentication.
    app.get "/signin/signin_using_openid_provider" do
      provider = OPENID_PROVIDERS_ARRAY[params[:provider_id].to_i]
      halt 400, "OpenID provider not found." unless provider
      redirect OpenidProvider.get_openid_login_redirect(provider, request, session)
    end

    app.get "/signin/select_openid_provider" do
      erb :select_openid_provider, :locals => { :openid_providers => OPENID_PROVIDERS_ARRAY }
    end

    # Handle login complete from openid provider.
    app.get "/signin/complete" do
      @openid_consumer ||= OpenID::Consumer.new(session,
                                                OpenID::Store::Filesystem.new(
                                                  File.join(File.dirname(__FILE__), "/tmp/openid")))
      openid_response = @openid_consumer.complete(params, request.url)
      case openid_response.status
      when OpenID::Consumer::FAILURE
        "Sorry, we could not authenticate you with this identifier. #{openid_response.display_identifier}"
      when OpenID::Consumer::SETUP_NEEDED then "Immediate request failed - Setup Needed"
      when OpenID::Consumer::CANCEL then "Login cancelled."
      when OpenID::Consumer::SUCCESS
        ax_resp = OpenID::AX::FetchResponse.from_success_response(openid_response)
        email = ax_resp["http://axschema.org/contact/email"][0]
        if defined?(PERMITTED_USERS) && !PERMITTED_USERS.empty?
          unless PERMITTED_USERS.split(",").map(&:strip).include?(email)
            halt 401, "Your email #{email} is not authorized to login to Barkeep."
          end
        end
        session[:email] = email
        unless User.find(:email => email)
          # If there are no admin users yet, make the first user to log in the first admin.
          permission = User.find(:permission => "admin").nil? ? "admin" : "normal"
          User.new(:email => email, :name => email, :permission => permission).save
        end
        redirect session[:login_started_url] || "/"
      end
    end
  end
end
