# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.synced_folder ".", "/vagrant"
  config.vm.provider "virtualbox" do |v|
    v.memory = 2048
  end
  config.vm.provision "shell", path: "bootstrap.sh"
  config.vm.define :cd, primary: true do |cd|
    cd.vm.network :forwarded_port, host: 8080, guest: 8080
    cd.vm.network :forwarded_port, host: 5000, guest: 5000
    cd.vm.network :forwarded_port, host: 2201, guest: 22, id: "ssh", auto_correct: true
    cd.vm.network "private_network", ip: "192.168.50.91"
    cd.vm.provision :shell, inline: 'ansible-playbook /vagrant/ansible/cd.yml -c local'
  end
  config.vm.define :prod do |prod|
    prod.vm.network :forwarded_port, host: 2202, guest: 22, id: "ssh", auto_correct: true
    prod.vm.network "private_network", ip: "192.168.50.92"
    prod.vm.provision :shell, inline: 'ansible-playbook /vagrant/ansible/prod.yml -c local'
  end
  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
  end
end