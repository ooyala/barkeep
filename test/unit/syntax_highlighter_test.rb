require File.expand_path(File.join(File.dirname(__FILE__), "../unit_test_helper.rb"))
require "lib/syntax_highlighter.rb"

class SyntaxHighlighterTest < Scope::TestCase
  context "pygmentize" do
    should "handle a language by alias" do
      highlighted = SyntaxHighlighter.pygmentize("ruby", "foo")
      assert_match /span/, highlighted
    end

    should "handle a language by filename" do
      highlighted = SyntaxHighlighter.pygmentize("lisp", "foo")
      assert_match /span/, highlighted
    end

    should "return plaintext for an unrecognized language" do
      highlighted = SyntaxHighlighter.pygmentize("foobar", "foo")
      assert_equal "foo", highlighted
    end
  end
end
