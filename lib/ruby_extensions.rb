class String
  def starts_with?(string)
    self[0..string.size - 1] == string
  end
end