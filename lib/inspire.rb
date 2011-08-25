# Parses the lib/inspire.txt file and returns a randomized quotation by the Barkeep.
# To add a new part of speech, add the section to inspire.txt and then add the
# singular form to @@parts_of_speech. And by "singular form", I mean "remove the s".

class Inspire
  def initialize
    @@parts_of_speech ||= [ :noun, :verb, :adjective, :virtue, :vice ]
    @@transformations ||= [ :capital ]
    @@exclude_words = []
    parse_inspire_text
  end

  def quote
    phrase = random_element(@@phrases)
    @@parts_of_speech.each do |part_of_speech|
      phrase = phrase.gsub("*#{part_of_speech}*") do |match|
        get_random_part_of_speech_and_exclude(part_of_speech)
      end
      @@transformations.each do |transformation|
        phrase = phrase.gsub("*#{transformation}-#{part_of_speech}*") do |match|
          self.send(:"#{transformation}", get_random_part_of_speech_and_exclude(part_of_speech))
        end
      end
    end
    @@exclude_words = []
    phrase
  end

  private

  def parse_inspire_text
    return if defined?(@@phrases)
    @@raw_text = IO.read("#{File.dirname(__FILE__)}/inspire.txt")
    @@phrases  = parse_part_of_speech(:phrase)
    @@parts_of_speech.each do |part_of_speech|
      self.class.class_variable_set(:"@@#{part_of_speech}s", parse_part_of_speech(part_of_speech))
    end
  end

  def parse_part_of_speech(part_of_speech)
    /# #{part_of_speech.capitalize}s\s([^#]+)/.match(@@raw_text)[1].split("\n") rescue []
  end

  def random_element(array)
    array[rand(array.size)]
  end

  def get_random_part_of_speech_and_exclude(part_of_speech)
    word_array = self.class.class_variable_get(:"@@#{part_of_speech}s")
    word = random_element(word_array - @@exclude_words)
    @@exclude_words << word
    word
  end

  # Transformations
  def capital(word) word.capitalize end
end
