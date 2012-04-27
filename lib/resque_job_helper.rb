require "resque"

module ResqueJobHelper
  def self.included(klass) klass.extend(ClassMethods) end

  module ClassMethods
    # In any Resque worker, our SQL connection will be invalid because of the fork or if the connection
    # has timed out.
    def reconnect_to_database() DB[:users].select(1).first rescue nil end
  end
end
