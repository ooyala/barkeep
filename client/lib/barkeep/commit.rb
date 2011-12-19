require "rubygems"
require "trollop"
require "dedent"
require "net/http"
require "json"

require "barkeep/constants"

module BarkeepClient
  module Commands
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

      begin
        result = BarkeepClient.commits(configuration, repo, [sha])[sha]
      rescue RuntimeError => e
        puts e.message
        exit 1
      end

      result.each { |key, value| puts "  #{key.rjust(result.keys.map(&:size).max)}: #{value}" }
    end
  end

  # Core method for calling Barkeep's commit API call.
  # TODO: Support querying lots of commits at once using the altered API call.
  def self.commits(configuration, repo, shas)
    result = {}
    shas.each do |sha|
      uri = URI.parse(File.join(configuration["barkeep_server"], "/api/commits/#{repo}/#{sha}"))
      response = Net::HTTP.get_response uri
      if response.code.to_i != 200
        error = JSON.parse(response.body)["message"] rescue nil
        raise error ? "Error: #{error}" : "Unspecified server error."
      end
      info = JSON.parse(response.body)
      commit_data = {}
      info.each do |key, value|
        next if value.nil?
        value = Time.at(value).strftime("%m/%d/%Y %I:%M%p") if key == "approved_at"
        commit_data[key] = value
      end
      result[sha] = commit_data
    end
    result
  end
end
