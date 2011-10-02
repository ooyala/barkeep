require "rake/testtask"
require "resque/tasks"

$LOAD_PATH.push("./") unless $LOAD_PATH.include?("./")
require "resque_jobs/db_commit_ingest"
require "resque_jobs/generate_tagged_diffs"
require "resque_jobs/fetch_commits"
require "resque_jobs/batch_comment_emails"
require "resque_jobs/deliver_comment_emails"

task :test => ["test:units", "test:integrations"]

namespace :test do
  Rake::TestTask.new(:units) do |task|
    task.libs << "test"
    task.test_files = FileList["test/unit/*"]
  end

  Rake::TestTask.new(:integrations) do |task|
    task.libs << "test"
    task.test_files = FileList["test/integration/*"]
  end
end

namespace :resque do
  desc "Start running all resque workers."
  task :start do
    puts `script/resque_workers.rb start`
  end

  desc "Stop running all resque workers."
  task :stop do
    puts `script/resque_workers.rb stop`
  end
end

namespace :clockwork do
  desc "Start running periodic jobs."
  task :start do
    puts `script/clockwork_jobs.rb start`
  end

  desc "Stop running periodic jobs."
  task :stop do
    puts `script/clockwork_jobs.rb stop`
  end
end