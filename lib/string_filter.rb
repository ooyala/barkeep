# StringFilter is a module mixed in to the String class.
# It defines filters that, when applied to the including String,
# substitute some text for other text. We use this for things like
# replacing shas in comments with a link to the commit.
#
# Additional filters can be easily plugged in here or externally
# by re-opening StringFilter.
#
# Possible extensions:
# * Convert APP-XXX to jira links
# * Make @username link to profile pages

module StringFilter
  def pygmentize
    RedcarpetManager.redcarpet_pygments.render(self)
  end

  def replace_shas_with_links(repo_name)
    self.gsub(/([a-zA-Z0-9]{40})/) do |sha|
      "<a href='/commits/#{repo_name}/#{sha}'>#{sha[0..6]}</a>"
    end
  end

  def link_github_issue(github_username, github_repo)
    # See https://github.com/blog/831-issues-2-0-the-next-generation
    # for the list of issue linking synonyms.
    self.gsub(/(#|gh-)(\d+)/i) do |match|
      "<a href='https://github.com/#{github_username}/#{github_repo}/issues/#{$2}' target='_blank'>" +
          "#{$1}#{$2}</a>"
    end
  end

  def newlines_to_html
    self.gsub("\n", "<br/>")
  end

  def escape_html
    CGI::escapeHTML(self)
  end
end

class String
  include StringFilter
end
