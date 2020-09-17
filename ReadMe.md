# About

This project is about installing Kubernetes via Puppet using Jenkins Jobs. The project contains Jenkins Job `(prepare_k8s_installation)` that will take in arguments from `env.yaml` file and then installs Kubernetes via `puppetlabs/kubernetes` module. Following things are going to be added on Puppet Agent VMs.

1. Docker 
2. Puppetlabs/Kubernetes module
3. Puppetlabs/Firewall module
4. Hiera.yaml file
5. RedHat.yaml file
6. Site.pp file

# Prerequisite

* Puppet Environment is set up on VMs. (Puppet Master and Puppet Agent)
* **SSH**ability to all Puppet Agent VMs from Jenkins agent.
* Sudo privilege access on all VMs. The Jenkins Job will need to perform certain tasks on agents that will require sudo privileges. 
* Jenkins credential that can be used to access all Puppet VMs. Need to setup with credential ID `jenkinsSshID`. The credential is of type `sshKeyFile` which contains SSH Private Key of a user with which Jenkins will login into puppet agents. 