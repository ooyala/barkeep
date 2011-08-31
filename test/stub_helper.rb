# A set of methods for stubbing out objects from our database. Some objects have lots of dependencies. These
# methods make creating those stubbed objects less work and less repetitive.
module StubHelper

  # Creates a Commit.
  # - user: a User who is the author of this commit.
  def stub_commit(user)
    commit = Commit.new
    stub(commit).git_repo { GitRepo.new(:name => "my_repo") }
    stub(commit).user { user }

    commit_author = user.name.dup
    stub(commit_author).user { user }
    grit_commit = OpenStruct.new(
        :short_message => "message", :id_abbrev => "commit_id",
        :author => commit_author, :date => Time.now, :diffs => [])
    stub(commit).grit_commit { grit_commit }
    commit
  end
end