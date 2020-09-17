## site.pp ##

# This file (/etc/puppetlabs/puppet/manifests/site.pp) is the main entry point
# used when an agent connects to a master and asks for an updated configuration.
#
# Global objects like filebuckets and resource defaults should go in this file,
# as should the default node definition. (The default node can be omitted
# if you use the console and don't define any other nodes in site.pp. See
# http://docs.puppetlabs.com/guides/language_guide.html#nodes for more on
# node definitions.)

## Active Configurations ##

# Disable filebucket by default for all File resources:
File { backup => false }

# DEFAULT NODE
# Node definitions in this file are merged with node data from the console. See
# http://docs.puppetlabs.com/guides/language_guide.html#nodes for more on
# node definitions.

# The default node definition matches any node lacking a more specific node
# definition. If there are no other nodes in this file, classes declared here
# will be included in every node's catalog, *in addition* to any classes
# specified in the console for that node.

node /#{KUBERNETES_MASTER}#/ {
    class { 'kubernetes':
      controller => true,
    }
   class { 'firewalld': }
     firewalld_port { 'etcd-client':
       ensure   => present,
       zone     => 'public',
       port     => 2379,
       protocol => 'tcp',
     }
      firewalld_port { 'etcd-peer':
       ensure   => present,
       zone     => 'public',
       port     => 2380,
       protocol => 'tcp',
     }
      firewalld_port { 'kubelet':
       ensure   => present,
       zone     => 'public',
       port     => 6443,
       protocol => 'tcp',
     }
      firewalld_port { 'kube-proxy':
       ensure   => present,
       zone     => 'public',
       port     => 10250,
       protocol => 'tcp',
     }
      firewalld_port { 'cilium-vxlan-overlay':
        ensure   => present,
        zone     => 'public',
        port     => 8472,
        protocol => 'udp',
      }
      firewalld_port { 'cilium-health-check':
        ensure   => present,
        zone     => 'public',
        port     => 4240,
        protocol => 'tcp',
      }
}

node /#{KUBERNETES_WORKERS}#/ {
    class { 'kubernetes':
      worker => true,
    }
    firewalld_port { 'cilium-vxlan-overlay':
      ensure   => present,
      zone     => 'public',
      port     => 8472,
      protocol => 'udp',
    }
    firewalld_port { 'cilium-health-check':
      ensure   => present,
      zone     => 'public',
      port     => 4240,
      protocol => 'tcp',
    }
}
