namespace :fezzik do
  namespace :coffeescript do
    remote_task :install do
      puts "running coffeescript install"
      run "add-apt-repository ppa:gezakovacs/coffeescript && apt-get update && apt-get install -y coffeescript"
    end
  end
end
