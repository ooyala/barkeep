# A set of methods for stubbing out objects from our database. Some objects have lots of dependencies. These
# methods make creating those stubbed objects less work and less repetitive.
module StubHelper

  # Creates a Commit.
  # - user: a User who is the author of this commit.
  def stub_commit(repo_name, sha, user)
    commit = Commit.new(:sha => sha)
    stub(commit).git_repo { GitRepo.new(:name => repo_name) }
    stub(commit).user { user }

    commit_author = user.name.dup
    stub(commit_author).user { user }
    grit_commit = OpenStruct.new(
        :id => sha, :sha => sha, :id_abbrev => sha,
        :repo_name => repo_name,
        :short_message => "message", :author => Grit::Actor.new(user.name, user.email),
        :date => Time.now, :diffs => [])
    stub(commit).grit_commit { grit_commit }
    commit
  end
end

# This dataset stub can be used to spy on the parameters being sent through our datasets. Use it like this:
# @dataset = DatasetStub.new([movie1, movie2])
# Movie.stubs(:dataset).returns(@dataset)
class DatasetStub < Array
  attr_accessor :params
  def initialize(array = [])
    @array = array
    @params = {}
    super
  end

  def all(*args) self end
  def order(*args) params[:order] = args; self end
  def filter(*args) params[:filter] = args; self end
  def limit(*args) params[:limit] = args; self end
  def and(*args) params[:and] = args; self end
  def or(*args) params[:or] = args; self end
  def select(*args) params[:select] = args; self; end
  def update(*args) params[:update] = args; self end
  def first(*args) params[:first] = args; @array.first end
  def server(server) params[:server] = server; self end
  def delete(*args) self end
  def eager(*args) self end
  def eager_graph(*args) self end
  def qualify() self end
  def distinct() self end
  def with_sql(sql) self end
  def model() Class end
  def sql() "" end
  def first_source_alias() "" end
end
