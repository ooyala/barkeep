require "faraday"
require "json"

OAUTH_ENDPOINT = "https://accounts.google.com/o/oauth2/auth"
TOKEN_ENDPOINT = "https://www.googleapis.com/oauth2/v3/token"
IDENTITY_ENDPOINT = "https://www.googleapis.com/oauth2/v2/userinfo"

credentials_filename = File.expand_path(File.join(File.dirname(__FILE__),
                                                  "../../config/google-oauth2-credentials.json"))
CREDENTIALS = (File.exist?(credentials_filename) ? JSON.parse(File.read(credentials_filename)) : nil)

module GoogleOAuth2
  def self.validate_configuration
    if CREDENTIALS.nil?
      raise "No credentials file found"
    elsif CREDENTIALS["web"]["redirect_uris"].size == 0
      raise "No redirect uri configured"
    end
  end

  def self.fetch_email(authorization_code)
    validate_configuration()

    token_response = Faraday.post(TOKEN_ENDPOINT, {
      :code => authorization_code,
      :client_id => CREDENTIALS["web"]["client_id"],
      :client_secret => CREDENTIALS["web"]["client_secret"],
      :redirect_uri => CREDENTIALS["web"]["redirect_uris"].first,
      :grant_type => "authorization_code"
    })
    tokens = JSON.parse(token_response.body)

    identity_response = Faraday.get(IDENTITY_ENDPOINT, { :access_token => tokens["access_token"] })
    userinfo = JSON.parse(identity_response.body)

    userinfo["email"]
  end

  # Entry point for user signin. The user will be redirected to this url to start authentication. This
  # provider is expected set the user's email set inside session[:email] when signin is complete, or show an
  # error if signin fails.
  def self.signin_url(request, session)
    validate_configuration()

    params = {
      :response_type => "code",
      :client_id => CREDENTIALS["web"]["client_id"],
      :redirect_uri => CREDENTIALS["web"]["redirect_uris"].first,
      :scope => "email"
    }

    OAUTH_ENDPOINT + "?" + params.map { |k, v| "#{k}=#{v}" }.join("&")
  end

  # Routes for authentication are defined here, and will be processed by Sinatra when this module is
  # registered.
  def self.registered(app)
    app.get "/signin/complete" do
      email = GoogleOAuth2::fetch_email(params["code"])

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
