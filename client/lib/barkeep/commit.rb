require "rubygems"
require "trollop"
require "dedent"
require "rest_client"
require "json"

require "barkeep/constants"

module BarkeepClient
  module Commands
    def self.commit(configuration)
      options = Trollop.options do
        banner <<-EOS.dedent
          Barkeep's 'commit' command shows information about a particular commit given its SHA.

          Usage:
              $ barkeep commit [options] <commit>
          where <commit> is specified as a (partial) SHA-1 hash (for the current repo) or as, for example,
              myrepo/d29a4a0fa
          to specify a particular repository, and [options] can include:
        EOS
      end
      Trollop.die "must provide a commit sha" unless ARGV.size == 1

      begin
        repo, sha = Commands.parse_commit(ARGV[0])
      rescue RuntimeError => e
        Trollop.die e.message
      end

      begin
        result = BarkeepClient.commits(configuration, repo, [sha]).values[0]
      rescue RuntimeError => e
        puts e.message
        exit 1
      end

      result.each { |key, value| puts "  #{key.rjust(result.keys.map(&:size).max)}: #{value}" }
    end

    def self.parse_commit(commit_specification)
      case commit_specification
      when %r{^[^/]+/#{SHA_REGEX}$} # foo/abc123
        commit_specification.split "/"
      when /^#{SHA_REGEX}$/ # abc123
        repo = File.basename(`git rev-parse --show-toplevel`).strip
        if repo.empty?
          raise "need to be in a git repo or specify a repository (e.g. myrepo/abc123)"
        end
        [repo, commit_specification]
      else
        raise "#{commit_specification} is an invalid commit specification"
      end
    end
  end

  # Core method for calling Barkeep's commit API call.
  def self.commits(configuration, repo, shas, fields = [])
    result = {}
    params = { :shas => shas.join(",") }
    params[:fields] = fields.join(",") unless fields.empty?
    begin
      response = RestClient.post "http://#{configuration["barkeep_server"]}/api/commits/#{repo}", params
    rescue SocketError
      raise "Cannot connect to the Barkeep server at http:#{configuration["barkeep_server"]}."
    end
    if response.code != 200
      error = JSON.parse(response.body)["message"] rescue nil
      raise error ? "Error: #{error}" : "Unspecified server error."
    end
    commits = JSON.parse(response.body)
    commits.each do |sha, info|
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
