require "lib/string_filter"
require "lib/redcarpet_extensions"
require "lib/emoji"
require "set"

StringFilter.define_filter :markdown do |str|
  RedcarpetManager.redcarpet_pygments.render(str)
end

# Converts repo:sha to a link to the commit.
# If repo: is omitted the provided repo_name is used.
StringFilter.define_filter :replace_shas_with_links do |str, repo_name, options = {}|
  # Examples: barkeep:9097e16494a7893c4724e5fbf1a77115d066403b
  #           9097e16494a7893c4724e5fbf1a77115d066403b
  # Only matches when string starts a line or is preceded by a space character.
  str.gsub(/(^|\s)(([a-zA-Z0-9_-]+):)?([a-zA-Z0-9]{40})/m) do
    repo = Regexp.last_match(3) || repo_name
    sha = Regexp.last_match(4)
    if options[:skip_markdown]
      " <a href='/commits/#{repo}/#{sha}' target='_blank'>#{sha[0..6]}</a>"
    else
      " [#{sha[0..6]}](/commits/#{repo}/#{sha})"
    end
  end
end

# Add Ooyala-specific Jira links. This list is from https://jira.corp.ooyala.com/secure/BrowseProjects.jspa#all
# TODO(philc): We'll be removing this out of Core barkeep soon. See issue #238.
JIRA_WHITELIST = Set.new(["BL", "PROD", "PL", "APP", "OCS", "BIG", "CCC", "CST", "DS", "IOS", "JIRA", "NH",
    "PSE", "OTA", "TOOL", "OTS", "WEB", "MIRA", "PWS", "AUTO", "HELP"])
StringFilter.define_filter :link_jira_issue do |str|
  str.gsub(/([A-Z]+)-(\d+)/) do |match|
    group = Regexp.last_match(1)
    next match unless JIRA_WHITELIST.include?(group)
    number = Regexp.last_match(2)
    "<a href='https://jira.corp.ooyala.com/browse/#{group}-#{number}' target='_blank'>" +
        "#{match}</a>"
  end
end

StringFilter.define_filter(:emoji) { |str| Emoji.emojify(str) }

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
