require "rubygems"
require "trollop"
require "dedent"
require "net/http"
require "json"

require "barkeep/constants"

module BarkeepClient
  def self.commit(configuration)
    options = Trollop::options do
      banner <<-EOS.dedent
        Barkeep's 'commit' command shows information about a particular commit given its SHA.

        Usage:
            $ barkeep commit [options] <commit>
        where <commit> is specified as a (partial) SHA-1 hash (for the current repo) or as, for example,
            myrepo/d29a4a0fa
        to specify a particular repository, and [options] can include:
      EOS
    end
    Trollop::die "must provide a commit sha" unless ARGV.size == 1

    commit = ARGV[0]
    repo, sha = case commit
                when %r{^[^/]+/#{SHA_REGEX}$} # foo/abc123
                  commit.split "/"
                when /^#{SHA_REGEX}$/ # abc123
                  repo = File.basename(`git rev-parse --show-toplevel`).strip
                  if repo.empty?
                    Trollop::die "need to be in a git repo or specify a repository (e.g. myrepo/abc123)"
                  end
                  [repo, commit]
                else
                  Trollop::die "#{commit} is an invalid commit specification"
                end
    uri = URI.parse(File.join(configuration["barkeep_server"], "/api/commits/#{repo}/#{sha}"))
    result = Net::HTTP.get_response uri
    if result.code.to_i != 200
      error = JSON.parse(result.body)["message"] rescue nil
      puts error ? "Error: #{error}" : "Unspecified server error."
      exit 1
    end
    info = JSON.parse(result.body)
    info.each do |key, value|
      next if value.nil?
      value = Time.at(value).strftime("%m/%d/%Y %I:%M%p") if key == "approved_at"
      puts "  #{key.rjust(info.keys.map(&:size).max)}: #{value}"
    end
  end
end
