require "trollop"
require "dedent"

require "barkeep/commit"

module BarkeepClient
  module Commands
    def self.view(configuration)
      options = Trollop.options do
        banner <<-EOS.dedent
          Barkeep's 'view' command opens the Barkeep commit page for a commit.

          Usage:
              $ barkeep view [options] <commit>
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
        result = BarkeepClient.commits(configuration, repo, [sha])[sha]
      rescue RuntimeError => e
        puts e.message
        exit 1
      end

      # Try xdg-open (linux) open (mac os). Otherwise throw an error.
      open_command = ["xdg-open", "open"].reject { |c| `which #{c}`.empty? }.first
      unless open_command
        puts "No application available to open a url (tried 'xdg-open' and 'open')."
        exit 1
      end

      puts `#{open_command} #{result["link"]}`
    end
  end
end
