# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "fedora/26-cloud-base"
  config.vm.box_version = "20170705"

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  config.vm.network "private_network", type: 'dhcp'

  config.vm.network "forwarded_port", guest: 8080, host: 8080, auto_correct: true

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
   config.vm.provider "virtualbox" do |vb|
     vb.memory = "1024"
     vb.cpus = 2
   end

  # View the documentation for the provider you are using for more
  # information on available options.
  config.vm.synced_folder ".", "/vagrant", type: 'virtualbox'

  config.vm.synced_folder ".", "/home/vagrant/app", type: 'rsync',
    rsync__exclude: %w[lua_modules .git .vagrant node_modules t/servroot t/servroot* ],
    rsync__args: %w[--verbose --archive --delete -z --links ]

  config.vm.provision "shell", path: 'script/install/centos.sh'
  config.vm.provision "shell", path: 'script/install/utilities.sh'
  
  config.vm.provision "shell", inline: <<~'SHELL'
     systemctl start redis
     systemctl disable openresty
     systemctl stop openresty
  SHELL

  config.vm.provision "shell", privileged: false, name: "Install APIcast dependencies", path: 'script/install/apicast.sh', args: %w[app]
end
