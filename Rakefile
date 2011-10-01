require "rake/testtask"
require "resque/tasks"

$LOAD_PATH.push("./") unless $LOAD_PATH.include?("./")
require "resque_jobs/db_commit_ingest"
require "resque_jobs/generate_tagged_diffs"
require "resque_jobs/fetch_commits"

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
  desc "Watch all resque queues and perform any work that shows up."
  task :run_all_workers do
    ENV["QUEUE"] = "*"
    Rake::Task["resque:work"].invoke
  end
end

namespace :clockwork_jobs do
  desc "Start running periodic jobs."
  task :start do
    puts `script/clockwork_jobs.rb start`
  end

  desc "Stop running periodic jobs."
  task :stop do
    puts `script/clockwork_jobs.rb stop`
  end
end