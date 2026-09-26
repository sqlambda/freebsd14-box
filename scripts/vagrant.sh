#!/bin/sh
# Install the Vagrant insecure public keys (RSA and ed25519) for the vagrant
# user. Vagrant swaps them for a per-machine key on first `vagrant up`.
set -eux

install -d -o vagrant -g vagrant -m 0700 /home/vagrant/.ssh
install -o vagrant -g vagrant -m 0600 /tmp/vagrant.pub /home/vagrant/.ssh/authorized_keys
rm -f /tmp/vagrant.pub

# Reverse DNS lookups on the libvirt network only slow logins down.
sed -i '' -e 's/^#\{0,1\}UseDNS .*/UseDNS no/' /etc/ssh/sshd_config
grep -q '^UseDNS no' /etc/ssh/sshd_config || echo 'UseDNS no' >> /etc/ssh/sshd_config
