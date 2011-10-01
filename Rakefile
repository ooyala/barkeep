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
  task :run_all_workers do
    ENV["QUEUE"] = "*"
    Rake::Task["resque:work"].invoke
  end
end

namespace :clockwork_jobs do
  task :start do
    puts `script/clockwork_jobs.rb start`
  end

  task :stop do
    puts `script/clockwork_jobs.rb stop`
  end
end