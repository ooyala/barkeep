require "lib/string_filter"
require "lib/redcarpet_extensions"

StringFilter.define_filter :markdown do |str|
  RedcarpetManager.redcarpet_pygments.render(str)
end

StringFilter.define_filter :replace_shas_with_links do |str, repo_name|
  str.gsub(/([a-zA-Z0-9]{40})/) do |sha|
    "<a href='/commits/#{repo_name}/#{sha}'>#{sha[0..6]}</a>"
  end
end

# NOTE(dmac): Capital letters, a dash and numbers are pretty general.
# For example, this would also pick up someone using the GH-1 github issue syntax.
# One way to fix this might be to require a prefix: "jira:APP-1234".
StringFilter.define_filter :link_jira_issue do |str|
  str.gsub(/([A-Z]+)-(\d+)/) do |match|
    group = Regexp.last_match(1)
    number = Regexp.last_match(2)
    "<a href='https://jira.corp.ooyala.com/browse/#{group}-#{number}' target='_blank'>" +
        "#{match}</a>"
  end
end

# Converts an embedded image (![alt][link]) to also include
# a link to the same image.
StringFilter.define_filter :link_embedded_images do |str|
  str.gsub(/!\[.*\]\((.*)\)/) { |match| "[#{match}](#{Regexp.last_match(1)})" }
end


# See https://github.com/blog/831-issues-2-0-the-next-generation
# for the list of issue linking synonyms.
StringFilter.define_filter :link_github_issue do |str, github_username, github_repo|
  str.gsub(/(#|gh-)(\d+)/i) do
    prefix = Regexp.last_match(1)
    number = Regexp.last_match(2)
    "<a href='https://github.com/#{github_username}/#{github_repo}/issues/#{number}' target='_blank'>" +
        "#{prefix}#{number}</a>"
  end
end

StringFilter.define_filter :truncate_front do |str, max_length|
  abbreviator = "..."
  if str.length > max_length
    start_position = str.length - (max_length - abbreviator.length)
    abbreviator + str[start_position...str.length]
  else
    str
  end
end

StringFilter.define_filter(:newlines_to_html) { |str| str.gsub("\n", "<br/>") }
StringFilter.define_filter(:escape_html) { |str| CGI::escapeHTML(str) }
