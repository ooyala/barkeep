# StringFilter is used to attach filters to methods that return strings.
# Filters are defined using `StringFilter.define_filter`.
# It can then be mixed in to classes with `include StringFilter`.
#
# The including class gains the `add_filter` method, which accepts
# a name of one of its instance methods to filter and a block
# containing the filter code. The block may accept one or two
# arguments. The first argument is the string to perform the
# filter on. The second argument, if supplied, will be the instance
# on which the filter is being called.
#
# When the filtered method is desired the client calls
# `instance.filter_<method>`. For example, if the client wants a
# filtered commit message, they would call `commit.filter_message`.
#
# Filters can also be called on plain strings outside the context
# of a class.
#
# See commit.rb and comment.rb for examples.
#
# Possible extensions:
# * Make @username link to profile pages

module StringFilter
  def self.included(base)
    base.extend ClassMethods
    base.class_variable_set :@@filter_methods, Hash.new([])
  end

  module ClassMethods
    # Successive calls to add_filter will build up a mapping of
    # { method_name => [array of procs] }. When filter_<method>
    # is called, each of the procs will be called on the return
    # value of <method> and the final result is returned.
    def add_filter(method_name, &filter_block)
      filter_methods = self.class_variable_get(:@@filter_methods)
      filter_methods.merge!({ method_name => filter_methods[method_name] + [filter_block] })
      self.class_variable_set(:@@filter_methods, filter_methods)
      unless respond_to? :"filter_#{method_name}"
        send :define_method, :"filter_#{method_name}" do |*args|
          filters = self.class.class_variable_get(:@@filter_methods)[method_name]
          result = send method_name, *args
          filters.each do |filter|
            case filter.arity
            when 1 then result = filter.call result
            when 2 then result = filter.call result, self
            else raise Exception, "String filters must accept 1 or 2 arguments"
            end
          end
          result
        end
      end
    end
  end

  # Calling StringFilter.define_filter simply adds another module method
  # to the StringFilter module. It's not as scary as it looks.
  # Seriously, don't worry about it.
  def self.define_filter(name, &block)
    (class << self; self; end).send :define_method, name, block
  end
end
