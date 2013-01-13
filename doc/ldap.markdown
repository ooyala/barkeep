Barkeep's LDAP user authentication has been tested against OpenLDAP and Active Directory, but in a limited permutation of setups. If you have issues authenticating against a particular setup, please check your server configuration, talk to your sysadmin, and check the [open issues list](https://github.com/ooyala/barkeep/issues). If you still have trouble, please [open a new issue](https://github.com/ooyala/barkeep/issues/new).

## Unsupported features
LDAP group authentication is not supported, nor is any form of SSL encryption. Pull requests are welcome!

## Configuration
Add a hash to the list in `LDAP_PROVIDERS` in `environment.rb`. Barkeep supports multiple LDAP providers, and can be used in conjunction with any number of OpenID providers. However, usernames must be unique across all providers.

### Parameters
* `:name` : The name of this provider that will be displayed above the signin form. If multiple providers are specified, it will be used on the provider selection page.
* `:host` : The host name or IP address of the LDAP server.
* `:port` : The port to talk to on the LDAP server.
* `:base` : The RDN under which user accounts may be found.
* `:method` : The authentication type to use when binding. According to the net-ldap source code, it appears that supported values are `:simple`, `:anon`, `:anonymous`, `:sasl`, and `:gss_spnego`. **LDAP authentication has only been tested with `:simple`.**
* `:uid` : This can mean two different things, depending on whether `:username` is provided.

    If `:username` is not provided, it is used as the top-level attribute name used to construct the user's DN. It's probably something like `"CN"` or `"uid"`. For example, if `:uid` is `"CN"`, `:base` is `"OU=Developers,dc=company,dc=com"`, and the user provided `Joe Smith` as their username, then Barkeep will attempt to bind as `CN=Joe Smith,OU=Developers,dc=company,dc=com` with the password that the user provided.

    On the other hand, if `:username` is provided, `uid` is interpreted as the LDAP attribute to search for among the entries under `:base`. This is how Active Directory authentication via LDAP can work. Suppose `:uid` is set to `"employee_name"`, the user provided `jsmith` as their username, and `:base` is as before. Then Barkeep will bind as `:username` with `:password`, query the LDAP server for all entries under `OU=Developers,dc=company,dc=com`, and find the first entry whose attribute `employee_name` is `jsmith`. Let's say this entry is again `"CN=Joe Smith,OU=Developers,dc=company,dc=com"`. Barkeep will then attempt to bind as *that* DN, with the password the user provided. When authenticating with Active Directory, use `"sAMAccountName"` for `:uid`. If there is a cleaner way to accomplish these use cases, please do let us know.
* `:username` : (optional) The DN of to bind as when executing a query under `:base` for `:uid`. For an anonymous bind, specify as `""`. Active Directory also seems to let you get away with `"name@company.com", in lieu of a DN.
* `:password` : (optional) The password to go with `:username`. For an anonymous bind, specify as `""`.

## Examples

### OpenLDAP
    LDAP_PROVIDERS = [{
      :name => "OpenLDAP",
      :host => "ldap.example.com",
      :port => 389,
      :base => "OU=users,DC=example,DC=com",
      :method => :simple,
      :uid => "CN"
    }]

### Active Directory

#### Bind as DN
    LDAP_PROVIDERS = [{
      :name => "Active Directory",
      :host => "ad.example.com",
      :port => 389,
      :base => "OU=users,DC=example,DC=com",
      :method => :simple,
      :uid => "sAMAccountName",
      :username => "CN=Account Query Bot,OU=users,DC=example,DC=com",
      :password => "pass123"
    }]

#### Bind as username
    LDAP_PROVIDERS = [{
      :name => "Active Directory",
      :host => "ad.example.com",
      :port => 389,
      :base => "OU=users,DC=example,DC=com",
      :method => :simple,
      :uid => "sAMAccountName",
      :username => "account_query_bot@example.com",
      :password => "pass123"
    }]

#### Anonymous bind (untested)
    LDAP_PROVIDERS = [{
      :name => "Active Directory",
      :host => "ad.example.com",
      :port => 389,
      :base => "OU=users,DC=example,DC=com",
      :method => :simple,
      :uid => "sAMAccountName",
      :username => "",
      :password => ""
    }]
