class String
  def starts_with?(string)
    self[0..string.size - 1] == string
  end
end

class Object
  def blank?
    self.nil? || self == ""
  end
end

class Array
  alias :blank? :empty?
end

# Taken from ActiveSupport.
# http://rubydoc.info/gems/activesupport/3.1.0/Kernel#silence_stderr-instance_method
# Use this for running a Ruby block where you want to silence STDOUT or STDERR for the duration thereof.
def silence_stream(stream)
  old_stream = stream.dup
  stream.reopen("/dev/null")
  stream.sync = true
  yield
ensure
  stream.reopen(old_stream)
end