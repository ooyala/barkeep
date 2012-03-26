# A saved search represents a list of commits, some read and some unread.
#
# Columns:
# - email_commits: true if the user should be emailed when new commits are made which match this search.
# - email_comments: true if the user should be emailed when new comments are made.
class SavedSearch < Sequel::Model
  many_to_one :user

  PAGE_SIZE = 10

  # Used for demo user searches. When calling `.save` on the saved search of a demo user, rather than writing to
  # the database, we modify the saved_searches array in a demo user's session. Returning false cancels the
  # default save behavior.
  def before_save
    if user.demo?
      return false if @@session.nil?
      index = @@session[:saved_searches].index { |saved_search| saved_search[:id] == self.id }
      index ? @@session[:saved_searches][index] = self.values : @@session[:saved_searches] << self.values
      false
    else
      super
    end
  end

  # The list of commits this saved search represents.
  def commits(token = nil, direction = "before", min_commit_date)
    result = MetaRepo.instance.find_commits(
      :repos => repos_list,
      :branches => branches_list,
      :authors => authors_list,
      :paths => paths_list,
      :token => token,
      :direction => direction,
      :commit_filter_proc => self.unapproved_only ?
          self.method(:select_unapproved_commits).to_proc :
          self.method(:select_commits_currently_in_db).to_proc,
      :after => min_commit_date,
      :limit => PAGE_SIZE)
    page = (result[:count] / PAGE_SIZE).to_i + 1
    [result[:commits], page, result[:tokens]]
  end

  # True if this saved search's results include this commit.
  # NOTE(philc): This ignores the "unapproved_only" option of saved searches, because it's currently
  # being used to compute who to send comment emails to, and those computations should not care if a commit
  # has been approved yet.
  def matches_commit?(commit)
    MetaRepo.instance.search_options_match_commit?(commit.git_repo.name, commit.sha,
        :authors => authors_list,
        :paths => paths_list,
        :branches => branches_list,
        :repos => repos_list)
  end

  # Generates a human readable title based on the search criteria.
  def title
    return "All commits" if [repos, branches, authors, paths, messages].all?(&:nil?)
    if !repos.nil? && [authors, branches, paths, messages].all?(&:nil?)
      return "All commits for the #{comma_separated_list(repos_list)} " +
          "#{english_quantity("repo", repos_list.size)}"
    end

    message = ["Commits"]
    author_list = self.authors_list
    message << "by #{comma_separated_list(authors_list)}" unless authors_list.empty?
    message << "in #{comma_separated_list(paths_list)}" unless paths_list.empty?
    message << "on #{comma_separated_list(branches_list)}" unless branches_list.empty?
    unless repos_list.empty?
      message << "in the #{comma_separated_list(repos_list)} #{english_quantity("repo", repos_list.size)}"
    end
    message.join(" ")
  end

  def authors_list() (self.authors || "").split(",").map(&:strip) end
  def repos_list() (self.repos || "").split(",").map(&:strip) end

  def paths_list
    return [] unless self.paths && !self.paths.empty?
    JSON.parse(self.paths).map(&:strip)
  rescue []
  end

  def branches_list
    return "" unless self.branches
    self.branches.split(",").map(&:strip)
  end

  def self.create_from_search_string(search_string)
    parts = search_string.split(" ")
  end

  # TODO(dmac 3/26/12): Write tests for these demo saved search methods.

  # Used for demo user searches. To transparently support saving saved_searches for a demo user,
  # SavedSearch gets access to the Sinatra session hash. It also sets up the saved_searches array and
  # last_demo_saved_search_id which is used to generate ids for demo searches.
  def self.sync_session(session)
    @@session = session
    @@session[:saved_searches] ||= []
    @@session[:last_demo_saved_search_id] = 0 if @@session[:last_demo_saved_search_id].nil?
  end

  # Used for demo user searches. Creates a new SavedSearch object and automatically assigns a unique id to it.
  # Equivalent of `SavedSearch.new` for a demo user. Note that this does not actually save the object to the
  # session, the caller must call `.save` on the newly created object.
  def self.new_demo_search(options)
    options[:id] = (@@session[:last_demo_saved_search_id] += 1)
    SavedSearch.with_unrestricted_primary_key { SavedSearch.new(options) }
  end

  # Used for demo user searches. Deletes a saved search object from the session.
  def self.delete_demo_search(id)
    @@session[:saved_searches].delete_if { |saved_search| saved_search[:id] == id.to_i }
  end

  # Used for demo user searches. Equivalent to `SavedSearch[id]` for a demo user.
  def self.find_demo_search(id)
    options = @@session[:saved_searches].find { |saved_search| saved_search[:id] == id.to_i }
    SavedSearch.with_unrestricted_primary_key { SavedSearch.new(options) }
  end

  # Used for demo user searches. Returns all saved search objects of the logged in demo user.
  # Equivalent to `SavedSearch.filter(:user_id => current_user.id).to_a` for a demo user.
  def self.demo_saved_searches
    return [] if @@session.nil?
    searches = SavedSearch.with_unrestricted_primary_key do
      @@session[:saved_searches].map { |options| SavedSearch.new(options) }
    end
    searches.sort_by!(&:user_order).reverse!
  end

  def self.incremented_user_order(user)
    if user.demo?
      (@@session[:saved_searches].map { |saved_search| saved_search[:user_order] }.max || -1) + 1
    else
      (SavedSearch.filter(:user_id => user.id).max(:user_order) || -1) + 1
    end
  end

  private

  # Used for demo user searches. When passed a block, allows manual setting of the SavedSearch `id` field.
  # Sequel normally disallows this because `id` is a primary key. This is needed when assigning ids
  # to saved searches stored in a demo user session.
  def self.with_unrestricted_primary_key(&block)
    SavedSearch.unrestrict_primary_key
    return_value = block.call
    SavedSearch.restrict_primary_key
    return_value
  end

  # We asking for commits from Git, we can get back commits that are present on the filesystem (have been
  # pulled) but which have not had records created in the DB for them. Omit those commits from the saved
  # search for now, because they're not operable yet. You can't link to them, for example.
  def select_commits_currently_in_db(grit_commits)
    # This filter doesn't have any specific dataset criteria, other than the commits need to exist in the DB.
    select_commits_matching_dataset_criteria(grit_commits, {})
  end

  # This is used as a commit filter when fetching the commits which make up this saved search.
  # Note that this filter is a strict subset of the filter "select_commits_in_db".
  def select_unapproved_commits(grit_commits)
    select_commits_matching_dataset_criteria(grit_commits, :approved_by_user_id => nil)
  end

  # Finds matching database rows from the given set of grit_commits and ensures they also match the given
  # dataset filter.
  # - grit_commits: a list of grit commits. *These are assumed to all be from the same repo*.
  # - dataset_filter_options: a hash of filter options, to be passed to the Commit dataset's filter() method.
  # Returns a list of matching commits. The original order of the commits in grit_commits is preserved.
  def select_commits_matching_dataset_criteria(grit_commits, dataset_filter_options)
    return [] if grit_commits.empty?
    repo = GitRepo.first(:name => grit_commits.first.repo_name)
    raise "This commit does not have a repo_name set on it: #{grit_commits.first.sha}" unless repo
    commits_dataset = Commit.select(:sha).filter(:sha => grit_commits.map(&:sha), :git_repo_id => repo.id).
        filter(dataset_filter_options)
    commit_ids = Set.new(commits_dataset.all.map(&:sha))
    grit_commits.select { |grit_commit| commit_ids.include?(grit_commit.sha) }
  end

  def english_quantity(word, quantity) quantity == 1 ? word : word + "s" end

  def comma_separated_list(list)
    case list.size
    when 0 then ""
    when 1 then list[0]
    when 2 then "#{list[0]} and #{list[1]}"
    else "#{list[0..-2].join(", ")}, and #{list[-1]}"
    end
  end
end
