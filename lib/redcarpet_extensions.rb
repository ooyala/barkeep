require "redcarpet"
require "lib/syntax_highlighter"

class RedcarpetManager
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
    # Leave this false, safe links is off so that replace_shas_with_links works with relative paths.
    :safe_links_only => false,
    :with_toc_data => false,
    :hard_wrap => true,
    :xhtml => false
  }

  def self.redcarpet_pygments
    return @@redcarpet_pygments if @@redcarpet_pygments
    renderer = HTMLwithPygments.new(RENDER_OPTIONS)
    @@redcarpet_pygments = Redcarpet::Markdown.new(renderer, EXTENSIONS)
  end
end

class HTMLwithPygments < Redcarpet::Render::HTML
  def block_code(code, language)
    language ||= :text
    "<div class=\"commentCode\"><pre>#{SyntaxHighlighter::pygmentize(language, code)}</pre></div>"
  end
end
