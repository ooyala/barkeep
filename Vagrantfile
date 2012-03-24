Vagrant::Config.run do |config|
  config.vm.box = "lucid64"
  config.vm.host_name = "barkeep-vagrant"
  config.vm.box_url = "http://files.vagrantup.com/lucid32.box"

  # Forward a port from the guest to the host, which allows for outside
  # computers to access the VM, whereas host only networking does not.
  config.vm.forward_port 8081, 5678

  # Have ssh be accessible through port 2250. Hard coding this so we don't collide with other vagrant vms.
  config.vm.forward_port 22, 2250
  config.ssh.port = 2250
end
