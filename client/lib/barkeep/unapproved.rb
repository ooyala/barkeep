require "rubygems"
require "trollop"
require "dedent"
require "json"

require "barkeep/constants"

module BarkeepClient
  module Commands
    def self.unapproved(configuration)
      options = Trollop.options do
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
      end
      Trollop.die "must provide a commit range" if ARGV.empty?

      repo = File.basename(`git rev-parse --show-toplevel`).strip
      if repo.empty?
        Trollop.die "need to be in a git repo"
      end

      commit_range = ARGV.map { |arg| "'#{arg}'" }.join(" ")
      commits_string = `git log --format='%H' #{commit_range}`
      exit(1) unless $?.to_i.zero?
      commits = commits_string.split("\n").map(&:strip)

      if commits.empty?
        puts "No commits in range."
        exit 0
      elsif commits.size > 1000
        puts "Warning: #{commits.size} commits in range. Lookup could be very slow. Proceed? [yN]"
        unless STDIN.gets.downcase.strip =~ /^y(es)?/
          puts "Aborting."
          exit 0
        end
      end

      begin
        commit_data = BarkeepClient.commits(configuration, repo, commits, ["approved"])
      rescue RuntimeError => e
        puts e.message
        exit 1
      end

      unapproved_commits = {}

      commit_data.each do |sha, commit|
        next if commit["approved"]
        author_name = `git log --format='%an' #{sha} -n 1`
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
end
