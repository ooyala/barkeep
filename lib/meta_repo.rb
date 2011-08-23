# A module that encapsulates operations over a collection of git repositories.

require "grit"

require "lib/grit_extensions"
require "lib/script_environment"

module MetaRepo
  def self.initialize_meta_repo(logger, repo_paths)
    logger.info "Initializing #{repo_paths.size} git repositories."
    # Let's keep this mapping in memory at all times -- we'll be hitting it all the time.
    @@repo_name_to_id = {}
    # A convenient lookup table for Grit::Repos keyed by both string name and db id.
    @@repo_names_and_ids_to_repos = {}
    repo_paths.each do |path|
      name = File.basename(path)
      logger.info "Initializing repo '#{name}' at #{path}."
      raise "Error: Already have repo named #{name}" if @@repo_name_to_id[name]
      id = GitRepo.find_or_create(:name => name, :path => path).id
      grit_repo = Grit::Repo.new(path)
      @@repo_name_to_id[name] = id
      @@repo_names_and_ids_to_repos[name] = grit_repo
      @@repo_names_and_ids_to_repos[id] = grit_repo
    end
  end

  def self.db_commit(repo_name, sha)
    Commit[:repo_id => @@repo_name_to_id[repo_name], :sha => sha]
  end

  def self.grit_commit(repo_name_or_id, sha)
    @@repo_names_and_ids_to_repos[repo_name_to_id].commit(sha)
  end

  def self.import_new_commits!

  end
end
