# Scans for comments which have been made by demo users, and deletes those which are an hour old.
# This job is only scheduled when Barkeep has "read-only demo mode" enabled

require "bundler/setup"
require "pathological"
require "lib/script_environment"
require "lib/resque_job_helper"

class DeleteOldCommentsByDemoUsers
  include ResqueJobHelper
  COMMENT_EXPIRATION = 60 * 60 # one hour
  @queue = :delete_old_comments_by_demo_users

  def self.perform
    setup
    old_comments = Time.now - COMMENT_EXPIRATION
    demo_users = User.filter(:permission => "demo").select(:id).all # There should only be one demo user.
    return if demo_users.empty?
    Comment.filter(:user_id => demo_users.map(&:id)).filter("created_at <= ?", old_comments).delete
  end
end

if $0 == __FILE__
  DeleteOldCommentsByDemoUsers.perform
end
