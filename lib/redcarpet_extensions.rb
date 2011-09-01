require "redcarpet"
require "pygments"
require "lib/syntax_highlighter"

class RedcarpetManager
  @@redcarpet_html = nil
  @@redcarpet_pygments = nil

  EXTENSIONS = {
    :no_intra_emphasis => true,
    :autolink => true,
    :tables => true,
    :fenced_code_blocks => true,
    :strikethrough => true,
    :lax_html_blocks => true,
    :space_after_headers => true,
    :superscript => false
  }

  RENDER_OPTIONS = {
    :filter_html => true,
    :no_images => false,
    :no_links => false,
    :no_styles => false,
    :safe_links_only => true,
    :with_toc_data => false,
    :hard_wrap => true,
    :xhtml => false
  }

  def self.redcarpet_html
    return @@redcarpet_html if @@redcarpet_html
    renderer = Redcarpet::Render::HTML.new(RENDER_OPTIONS)
    @@redcarpet_html = Redcarpet::Markdown.new(renderer, EXTENSIONS)
  end

  def self.redcarpet_pygments
    return @@redcarpet_pygments if @@redcarpet_pygments
    renderer = HTMLwithPygments.new(RENDER_OPTIONS)
    @@redcarpet_pygments = Redcarpet::Markdown.new(renderer, EXTENSIONS)
  end
end

class HTMLwithPygments < Redcarpet::Render::HTML
  def block_code(code, language)
    "<div class=\"code\"><pre>#{SyntaxHighlighter::pygmentize(language, code)}</pre></div>"
  end
end
