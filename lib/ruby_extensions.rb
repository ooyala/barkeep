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
