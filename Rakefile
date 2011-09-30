require "rake/testtask"
require "resque/tasks"

$LOAD_PATH.push("./") unless $LOAD_PATH.include?("./")
require "resque_jobs/db_commit_ingest"

task :test => ["test:units"]

namespace :test do
  Rake::TestTask.new(:units) do |task|
    task.libs << "test"
    task.test_files = FileList["test/unit/*"]
  end
end
