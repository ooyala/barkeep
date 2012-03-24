# This is small goal-oriented DSL for installing system components, similar in purpose to Chef and Puppet.
# It's inspired by Babushka (http://github.com/benhoskings/babushka) but is simpler and is tailored for
# provisioning a production webapp.
#
# Usage:
#
# require "system_setup_dsl"
# include SystemSetupDsl
# dep "my library" do
#   met? { (check if your dependency is met) }
#   meet { (install your dependency) }
# end
#
# TODO(philc): Gemify this.
#

require "fileutils"
require "digest/md5"

module SystemSetupDsl
  def dep(name)
    @dependencies ||= []
    # If a dep gets required or defined twice, only run it once.
    return if @dependencies.find { |dep| dep[:name] == name }
    @dependencies.push(@current_dependency = { :name => name })
    yield
  end
  def met?(&block) @current_dependency[:met?] = block end
  def meet(&block) @current_dependency[:meet] = block end
  def in_path?(command) `which #{command}`.size > 0 end
  def fail_and_exit(message) puts message; exit 1 end

  # Runs a command and raises an exception if its exit status was nonzero.
  # - silent: if false, log the command being run and its stdout. False by default.
  # - check_exit_code: raises an error if the command had a non-zero exit code. True by default.
  def shell(command, options = {})
    silent = (options[:silent] != false)
    puts command unless silent
    output = `#{command}`
    puts output unless output.empty? || silent
    raise "#{command} had a failure exit status of #{$?.to_i}" unless $?.to_i == 0
    true
  end

  def satisfy_dependencies
    STDOUT.sync = true # Ensure that we flush logging output as we go along.
    @dependencies.each do |dep|
      unless dep[:met?].call
        puts "* Dependency #{dep[:name]} is not met. Meeting it."
        dep[:meet].call
        fail_and_exit %Q("met?" for #{dep[:name]} is still false after running "meet".) unless dep[:met?].call
      end
    end
  end

  #
  # Common deps that all Ruby apps need for deployment.
  #

  def package_installed?(package) `dpkg -s #{package} 2> /dev/null | grep Status`.match(/\sinstalled/) end
  def install_package(package)
    # Specify a noninteractive frontend, so dpkg won't prompt you for info. -q is quiet; -y is "answer yes".
    shell "sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy #{package}"
  end

  def ensure_packages(*packages) packages.each { |package| ensure_package(package) } end
  def ensure_package(package)
    dep package do
      met? { package_installed?(package) }
      meet { install_package(package) }
    end
  end

  def gem_installed?(gem) `gem list '#{gem}'`.include?(gem) end

  def ensure_gem(gem)
    dep gem do
      met? { gem_installed?(gem) }
      meet { shell "gem install #{gem} --no-ri --no-rdoc" }
    end
  end

  # Ensures the file at dest_path is exactly the same as the one in source_path.
  # Invokes the given block if the file is changed. Use this block to restart a service, for instance.
  def ensure_file(source_path, dest_path, &on_change)
    dep dest_path do
      met? do
        raise "This file does not exist: #{source_path}" unless File.exists?(source_path)
        File.exists?(dest_path) && (Digest::MD5.file(source_path) == Digest::MD5.file(dest_path))
      end
      meet do
        FileUtils.cp(source_path, dest_path)
        on_change.call if on_change
      end
    end
  end

  def ensure_rbenv
    ensure_package "git-core"
    dep "rbenv" do
      met? { in_path?("rbenv") }
      meet do
        # These instructions are from https://github.com/sstephenson/rbenv/wiki/Using-rbenv-in-Production
        shell "wget -q -O - https://raw.github.com/fesplugas/rbenv-installer/master/bin/rbenv-installer | bash"
        # We need to run rbenv init after install, which adjusts the path. If exec is causing us problems
        # down the road, we can perhaps simulate running rbenv init without execing.
        unless ARGV.include?("--forked-after-rbenv") # To guard against an infinite forking loop.
          exec "bash -c 'source ~/.bashrc; #{$0} --forked-after-rbenv'" # $0 is the current process's name.
        end
      end
    end
  end

  # ruby_version is a rbenv ruby version string like "1.9.2-p290".
  def ensure_rbenv_ruby(ruby_version)
    ensure_rbenv
    ensure_packages "curl", "build-essential", "libxslt1-dev", "libxml2-dev", "libssl-dev"

    dep "rbenv ruby #{ruby_version}" do
      met? { `which ruby`.include?("rbenv") && `ruby -v`.include?(ruby_version.gsub("-", "")) }
      meet do
        puts "Installing Ruby will take about 5 minutes."
        shell "rbenv install #{ruby_version}"
        shell "rbenv rehash"
      end
    end
  end
end
