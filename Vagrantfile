Vagrant.configure("2") do |config|
  config.vm.box = "lucid64"
  config.vm.host_name = "barkeep-vagrant"
  config.vm.box_url = "http://files.vagrantup.com/lucid64.box"
  config.vm.provision :shell, :inline =>
      "sudo mkdir -p /root/.ssh && sudo cp /home/vagrant/.ssh/authorized_keys /root/.ssh/"

  # Forward a port from the guest to the host, which allows for outside
  # computers to access the VM, whereas host only networking does not.
  config.vm.network "forwarded_port", guest: 80, host: 8080

  # Have ssh be accessible through port 2250. Hard coding this so we don't collide with other vagrant vms.
  config.vm.network "forwarded_port", guest: 22, host: 2250
  config.ssh.port = 2250

  # More memory than the default, since we're running a lot of stuff (1GB)
  config.vm.provider("virtualbox") { |vb| vb.customize ["modifyvm", :id, "--memory", 1024] }
end
