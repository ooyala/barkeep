# StringFilter is a module mixed in to the String class.
# It defines filters that, when applied to the including String,
# substitute some text for other text. We use this for things like
# replacing shas in comments with a link to the commit.
#
# Additional filters can be easily plugged in here or externally
# by re-opening StringFilter.
#
# Possible extensions:
# * Make @username link to profile pages

module StringFilter
  def markdown
    RedcarpetManager.redcarpet_pygments.render(self)
  end

  def replace_shas_with_links(repo_name)
    self.gsub(/([^\w]|^)([0-9a-fA-F]{40})([^\w]|$)/) do
      sha = Regexp.last_match(2)
      "#{Regexp.last_match(1)}<a href='/commits/#{repo_name}/#{sha}'>#{sha[0..6]}</a>#{Regexp.last_match(3)}"
    end
  end

  # NOTE(dmac): Capital letters, a dash and numbers are pretty general.
  # For example, this would also pick up someone using the GH-1 github issue syntax.
  # One way to fix this might be to require a prefix: "jira:APP-1234".
  def link_jira_issue
    self.gsub(/([A-Z]+)-(\d+)/) do |match|
      group = Regexp.last_match(1)
      number = Regexp.last_match(2)
      "<a href='https://jira.corp.ooyala.com/browse/#{group}-#{number}' target='_blank'>" +
          "#{match}</a>"
    end
  end

  # See https://github.com/blog/831-issues-2-0-the-next-generation
  # for the list of issue linking synonyms.
  def link_github_issue(github_username, github_repo)
    self.gsub(/(#|gh-)(\d+)/i) do
      prefix = Regexp.last_match(1)
      number = Regexp.last_match(2)
      "<a href='https://github.com/#{github_username}/#{github_repo}/issues/#{number}' target='_blank'>" +
          "#{prefix}#{number}</a>"
    end
  end

  # Converts an embedded image (![alt][link]) to also include
  # a link to the same image.
  def link_embedded_images
    self.gsub(/!\[.*\]\((.*)\)/) { |match| "[#{match}](#{Regexp.last_match(1)})" }
  end

  def newlines_to_html
    self.gsub("\n", "<br/>")
  end

  def truncate_front(max_length)
    abbreviator = "..."
    if length > max_length
      start_position = length - (max_length - abbreviator.length)
      abbreviator + self[start_position...length]
    else
      self
    end
  end

  def escape_html
    CGI::escapeHTML(self)
  end
end

class String
  include StringFilter
end
