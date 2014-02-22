# Load a user's configuration

require "yaml"
require "dedent"

require "barkeep/constants"

module BarkeepClient
  def self.get_configuration
    begin
      configuration = YAML.load_file CONFIG_FILE
      raise "Bad file" if configuration == false # On empty yaml files or ones with only comments. Lame API
    rescue
      raise <<-EOS.dedent
        Error: #{CONFIG_FILE} must exist to specify barkeep server information,
        and it must be a valid YAML file.
      EOS
    end

    # Check the configuration
    unless REQUIRED_CONFIG_KEYS.all? { |key| configuration.include? key }
      error = "Error: the following configuration keys are required in your #{CONFIG_FILE}: " <<
              REQUIRED_CONFIG_KEYS.join(', ')
      raise error
    end

    # Tweak parameters for backwards compatibility:
    unless configuration["barkeep_server"] =~ %r{^https?://}
      configuration["barkeep_server"].prepend "http://"
    end

    configuration
  end
end
