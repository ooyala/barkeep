require "rake/testtask"
require "resque/tasks"

$LOAD_PATH.push("./") unless $LOAD_PATH.include?("./")
require "resque_jobs/db_commit_ingest"
require "resque_jobs/generate_tagged_diffs"

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
