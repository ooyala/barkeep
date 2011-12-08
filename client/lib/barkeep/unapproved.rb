require "rubygems"
require "trollop"
require "dedent"
require "net/http"
require "json"

require "barkeep/constants"

module BarkeepClient
  def self.unapproved(configuration)
    options = Trollop::options do
      banner <<-EOS.dedent
        Barkeep's 'unapproved' command shows information about a particular commit. It MUST be run from a git
        repository of the same name as the repository on the server.

        Usage:
            $ barkeep unapproved [options] <commit-range>
        where <commit-range> is a commit range specified using git's range syntax (see `man gitrevisions`).
        For example:

            $ barkeep unapproved abc123
            $ barkeep unapproved ^abc123 def456
            $ barkeep unapproved abc123..def456

        [options] can include:
      EOS
      opt :stop_on_unapproved, "Stop and print a message on the first unapproved commit."
    end
    Trollop::die "must provide a commit range" if ARGV.empty?

    repo = File.basename(`git rev-parse --show-toplevel`).strip
    if repo.empty?
      Trollop::die "need to be in a git repo"
    end

    commit_range = ARGV.join(" ")
    commits_string = `git log --format='%H' #{commit_range}`
    exit(1) unless $?.to_i.zero?
    commits = commits_string.split("\n").map(&:strip)

    if commits.empty?
      puts "No commits in range."
      exit 0
    elsif commits.size > 100
      puts "Warning: #{commits.size} commits in range. Lookup could be very slow. Proceed? [yN]"
      unless STDIN.gets.downcase.strip =~ /^y(es)?/
        puts "Aborting."
        exit 0
      end
    end

    unapproved_commits = {}
    commits.each do |sha|
      uri = URI.parse(File.join(configuration["barkeep_server"], "/api/commits/#{repo}/#{sha}"))
      result = Net::HTTP.get_response uri
      if result.code.to_i != 200
        error = JSON.parse(result.body)["message"] rescue nil
        puts error ? "Error: #{error}" : "Unspecified server error."
        exit 1
      end
      info = JSON.parse(result.body)
      next if info["approved"]
      author_name = `git log --format='%an' #{sha} -n 1`
      if options[:stop_on_unapproved]
        puts "Found unapproved commit #{sha} by #{author_name}"
        exit 1
      end
      unapproved_commits[sha] = author_name
    end

    if unapproved_commits.empty?
      puts "#{commits.size} approved commit(s) and no unapproved commits in the given range."
    else
      puts "#{commits.size - unapproved_commits.size} approved commit(s) and " <<
           "#{unapproved_commits.size} unapproved commit(s) in the given range."
      puts "Unapproved:"
      unapproved_commits.each { |sha, author| puts "#{sha} #{author}" }
      exit 1
    end
  end
end
