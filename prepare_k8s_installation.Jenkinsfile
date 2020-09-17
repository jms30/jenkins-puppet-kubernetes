#!groovy

def props
def remote = [:]
def puppet_agents_ips = []
def jobs = [:]
def etcd_hosts_list = []
String etcd_hosts = ""
remote.name = 'ConfigMaster'
remote.allowAnyHosts = true
String kubernetes_masters = ""
String kubernetes_workers = ""
String kub_workers = ""
String kub_masters = ""
pipeline {
    agent any
    stages {
		stage('Prepare') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: "jenkinsSshID", keyFileVariable: 'sshKeyFile')]){
                    script {
                        props = readYaml file: './pipelines/initvm/env.yml'
                        echo "Properties loaded --> ${props}"

                        etcd_version       = props.install_k8s.etcd_version
                        kubernetes_version = props.install_k8s.kubernetes_version
                        kubetool_version   = props.install_k8s.kubetool_version
                        docker_version     = props.install_k8s.docker_version
                        cilium_version     = props.install_k8s.cilium_version

                        vms = props.vms
                        if(vms == null || vms.size() == 0) {
                            error("vms is an empty array.")
                        }

                        vms.each {
                            vm = it
                            Map<String,String> vm_params = [:]
                            vm.each {
                                entry = it.toString()
                                if(entry != null && entry.trim().length() > 0) {
                                    if(!entry.contains("=")) {
                                        error("A given entry is malformed. Entry must be provided in <option>:<value> format in env.yaml file. See \'" + entry + "\'")
                                    }
                                    option = entry.substring(0, entry.indexOf("=")).trim()
                                    value = entry.substring(entry.indexOf("=") + 1).trim()
                                    if(option == null || option.length() == 0) {
                                        error("An option in the given entry \'" + entry + "\' is either null or empty. Expected non-empty string followed by \':\' in env.yaml file." )
                                    }
                                    if(value == null || value.length() == 0) {
                                        error("Value for corresponding option \'" + option + "\' in the given entry \'" + entry + "\' is either null or empty. Expected non-empty string after \':\' in env.yaml file." )
                                    }

                                    // All entries in the map are non-null, non-empty and trimmed.
                                    vm_params.put(option, value)
                                }
                            }

                            if(!vm_params.containsKey("hostname")) {
                                error("Hostname is not provided in vms entry \'" + vm + "\'. Expected an entry as \'hostname:<vm hostname>\'")
                            }
                            vm_hostname = vm_params.get("hostname")

                            vm_domainname = ""
                            if(vm_params.containsKey("domain")) {
                                vm_domainname = vm_params.get("domain")
                            }

                            if(!vm_params.containsKey("ip") || vm_params.get("ip").split("\\.").size() != 4) {
                                error("The IP of a VM \'" + vm_hostname + "\' is either not provided or malformed. Expected an IPv4 entry. Check input \'" + vm_params.get("ip") + "\'")
                            }
                            vm_ip = vm_params.get("ip")

                            if(!vm_params.containsKey("roles")) {
                                error("Role(s) is not provided for a VM \'$vm_hostname\'. Expected at least one role from set [\'puppetmaster\',\'puppetagent\',\'kubernetesmaster\',\'kubernetesworker\'].")
                            }
                            vm_roles = vm_params.get("roles").split(",")

                            // populate different variables based on roles.
                            vm_roles.each { r ->
                                role = r.toString().trim()
                                if(role == "puppetmaster") {
                                    remote.host = vm_ip
                                }
                                else if(role == "puppetagent") {
                                    puppet_agents_ips.add(vm_ip)
                                }
                                else if(role == "kubernetesmaster") {
                                    etcd_hosts+= vm_hostname + ( (vm_domainname.length() == 0) ? vm_domainname : "." + vm_domainname  ) + ":" + vm_ip + ","
                                    kubernetes_masters+= vm_hostname + ( (vm_domainname.length() == 0) ? vm_domainname : "." + vm_domainname  ) + ","
                                }
                                else if(role == "kubernetesworker") {
                                    kubernetes_workers+= vm_hostname + ( (vm_domainname.length() == 0) ? vm_domainname : "." + vm_domainname  ) + ","
                                }
                                else {
                                    error("Configured Role \'$role\' is not supported yet. Please provide any of \'puppetmaster,kubernetesmaster,puppetagent,kubernetesworker\'")
                                }
                            }
                        }

                        if(etcd_hosts.endsWith(",")) {
                            etcd_hosts = etcd_hosts.substring(0,etcd_hosts.length()-1)
                        }
                        echo "ETCD Hosts are -> " + etcd_hosts
                        etcd_hosts_list = Arrays.asList(etcd_hosts.split(","))

                        if(kubernetes_masters.endsWith(",")) {
                            kubernetes_masters = kubernetes_masters.substring(0,kubernetes_masters.length()-1)
                        }
                        echo "Kubernetes Masters are -> " + kubernetes_masters
                        kub_masters = "'" + kubernetes_masters.replace(",", "', '") +"'"
                        echo "Kubernetes Masters Site.pp are -> " + kub_masters

                        if(kubernetes_workers.endsWith(",")) {
                            kubernetes_workers = kubernetes_workers.substring(0,kubernetes_workers.length()-1)
                        }
                        echo "Kubernetes Workers are -> " + kubernetes_workers
                        kub_workers = "'" + kubernetes_workers.replace(",", "', '") +"'"
                        echo "Kubernetes Workers Site.pp are -> " + kub_workers

                        remote.user = props.initVM.ssh.user
                        remote.identity = props.initVM.ssh.key
                        remote.identityFile = "${sshKeyFile}"
                        // if(!props.initVM.ssh.keyFile.startsWith("/")) {
                        //     // Relative file paths don't seem to work properly in sshCommand:remote
                        //     remote.identityFile = "${WORKSPACE}/${props.initVM.ssh.keyFile}"
                        // }
                        remote.password = props.initVM.ssh.password
                        //remote.host = props.initVM.puppetagent.pa_puppet_master_hostname
                        echo "The configured remote.host is --> ${remote.host}"

                    }

                    contentReplace(
                        configs: [
                            variablesReplaceConfig(
                                emptyValue: "",
                                fileEncoding: 'UTF-8',
                                filePath: 'pipelines/install_k8s/generate_redhat_yaml.sh',
                                variablesPrefix: '#{',
                                variablesSuffix: '}#',
                                configs: [
                                    variablesReplaceItemConfig(
                                        name: 'etcd_version',
                                        value: "${etcd_version}"
                                    ),

                                    variablesReplaceItemConfig(
                                        name: 'kubernetes_version',
                                        value: "${kubernetes_version}"
                                    ),

                                    variablesReplaceItemConfig(
                                        name: 'kubetool_version',
                                        value: "${kubetool_version}"
                                    ),

                                    variablesReplaceItemConfig(
                                        name: 'docker_version',
                                        value: "${docker_version}"
                                    ),
                                    variablesReplaceItemConfig(
                                        name: 'cilium_version',
                                        value: "${cilium_version}"
                                    ),

                                    variablesReplaceItemConfig(
                                        name: 'etcd_hosts',
                                        value: "${etcd_hosts}"
                                    )]
                            )]
                    )

                    contentReplace(
                        configs: [
                            variablesReplaceConfig(
                                emptyValue: "",
                                fileEncoding: 'UTF-8',
                                filePath: 'pipelines/install_k8s/site.pp',
                                variablesPrefix: '#{',
                                variablesSuffix: '}#',
                                configs: [
                                    variablesReplaceItemConfig(
                                        name: 'KUBERNETES_MASTER',
                                        value: "${kub_masters}"
                                    ),

                                    variablesReplaceItemConfig(
                                        name: 'KUBERNETES_WORKERS',
                                        value: "${kub_workers}"
                                    )
                                ]
                            )
                        ]
                    )
                }
            }
        }

        stage('Install-Docker') {
			steps {
                withCredentials([sshUserPrivateKey(credentialsId: "jenkinsSshID", keyFileVariable: 'sshKeyFile')]){
                    script {
                        remote.identityFile = "${sshKeyFile}"
                        echo "Checking if Docker is already installed..."
                        response = sshCommand remote: remote, failOnError: false, command: "systemctl status docker && echo Status=\$? || echo Status=\$?"
                        if( response.indexOf("Active: inactive") > 0 ) {
                            error("Docker service is not running properly: \
                                Expected \"Active: active\", \"docker.service; enabled\" and \"Status=0\"")
                            // fix it yourself manually.
                        } else if( response.indexOf("Active: active (running) ") > 0 &&
                                response.indexOf("Status=0") > 0 ) {
                            echo "Docker.service is already installed and is running & enabled."
                        } else {
                            // install docker
                            tmp = "docker-ce-" + docker_version
                            echo "Docker is not installed on this device. Installing docker (version $tmp)..."
                            response = sshCommand remote: remote, command: "yum install -y ${tmp} && echo Status=\$? || echo Status=\$?", sudo: true
                            if( response.indexOf("Status=0") < 0 ) {
                                error("Failed to install docker. See response.\n" + response)
                                // fix it yourself manually.
                            }

                            echo "Enabling Docker Service..."
                            sshCommand remote:remote, command: "systemctl start docker.service --no-ask-password && sudo systemctl enable docker.service --no-ask-password && sudo systemctl daemon-reload --no-ask-password", sudo: true

                            echo "Checking Systemctl Docker Service ->"
                            response = sshCommand remote:remote, command: "systemctl status docker.service --no-ask-password "
                            if( response.indexOf("Active: active (running)") < 0 ) {
                                error("Docker is not installed properly. See response.\n" + response)
                            }

                            echo "Printing Docker Info..."
                            response = sshCommand remote:remote, command: "docker info && echo \$? || echo \$?", sudo: true
                            echo "Installing docker version $tmp --> Done."
                        }
                    }
                }
			}
		}

        stage('Install-Kubernetes-Module') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: "jenkinsSshID", keyFileVariable: 'sshKeyFile')]){
                    script {
                        remote.identityFile = "${sshKeyFile}"
                        echo "Checking if Puppetlabs-kubernetes module is already installed..."
                        response = sshCommand remote: remote, failOnError: false, command: "sudo -i puppet module list | grep puppetlabs-kubernetes", sudo: false
                        echo "Response: " + response
                        if( response != null && !response.isEmpty() ) {
                            echo "Puppetlabs-kubernetes Module is already installed."
                        } else {
                            response = sshCommand remote: remote, command: "sudo -i puppet module install puppetlabs-kubernetes && echo \$? || echo \$?", sudo: false
                            temp = response?.split("\n")
                            if( temp == null || temp[temp.length - 1] != "0") {
                                error("Failed to install puppetlabs-kubernetes module. See response.\n" + response)
                            }
                            echo "Install Puppetlabs-kubernetes Module --> Done."
                        }
                    }
                }
            }
        }

        stage('Install-Firewall-Module') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: "jenkinsSshID", keyFileVariable: 'sshKeyFile')]){
                    script {
                        remote.identityFile = "${sshKeyFile}"
                        echo "Checking if Puppet-firewalld module is already installed..."
                        response = sshCommand remote: remote, failOnError: false, command: "sudo -i puppet module list | grep puppet-firewalld", sudo: false
                        echo "Response: " + response
                        if( response != null && !response.isEmpty() ) {
                            echo "Puppet-firewalld Module is already installed."
                        } else {
                            response = sshCommand remote: remote, command: "sudo -i puppet module install puppet-firewalld && echo \$? || echo \$?", sudo: false
                            temp = response?.split("\n")
                            if( temp == null || temp[temp.length - 1] != "0") {
                                error("Failed to install puppet-firewalld module. See response.\n" + response)
                            }
                            echo "Install Puppet-firewalld Module --> Done."
                            // Dirty hack because artifactory isn't working so we can have a
                            // local copy of the firewalld module without this setting being "true".
                            sshCommand remote: remote, failOnError: true, command: "sed -i 's/refreshonly => true/refreshonly => false/' /etc/puppetlabs/code/environments/production/modules/firewalld/manifests/reload.pp", sudo: true
                            sshCommand remote: remote, failOnError: true, command: "sed -i 's/refreshonly => true/refreshonly => false/' /etc/puppetlabs/code/environments/production/modules/firewalld/manifests/reload/complete.pp", sudo: true
                        }
                    }
                }
            }
        }

        stage('Generate-Hiera-Yaml') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: "jenkinsSshID", keyFileVariable: 'sshKeyFile')]){
                    script {
                        remote.identityFile = "${sshKeyFile}"
                        sshPut remote: remote, from: "pipelines/install_k8s/hiera.yaml", into: '.'
                        response = sshCommand remote:remote, command: "cp ./hiera.yaml /etc/puppetlabs/code/environments/production/", sudo: true
                        echo "Generate Hiera.yaml file --> Done."
                    }
                }
            }
        }

        stage('Generate-RedHat-Yaml') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: "jenkinsSshID", keyFileVariable: 'sshKeyFile')]){
                    script {
                        remote.identityFile = "${sshKeyFile}"
                        sshPut remote: remote, from: "pipelines/install_k8s/generate_redhat_yaml.sh", into: '.'
                        sshCommand remote: remote, command: "chmod +x ./generate_redhat_yaml.sh"
                        response = sshCommand remote:remote, command: "./generate_redhat_yaml.sh", sudo: true
                        echo "Generate RedHat.yaml and necessary agent.yaml files --> Done."
                    }
                }
            }
        }

        stage('Generate-Site-Pp') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: "jenkinsSshID", keyFileVariable: 'sshKeyFile')]){
                    script {
                        remote.identityFile = "${sshKeyFile}"
                        sshPut remote: remote, from: "pipelines/install_k8s/site.pp", into: '.'
                        response = sshCommand remote:remote, command: "puppet parser validate ./site.pp && echo \$? || echo \$?", sudo: false
                        temp = response?.split("\n")
                        if( temp == null || temp[temp.length - 1] != "0") {
                            error("Site.pp file is invalid. Response:\n" + response)
                        }
                        response = sshCommand remote:remote, command: "cp ./site.pp /etc/puppetlabs/code/environments/production/manifests/", sudo: true
                        echo "Copy site.pp file to necessary directory --> Done."
                    }
                }
            }
        }

        stage('Run-Agents') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: "jenkinsSshID", keyFileVariable: 'sshKeyFile')]){
                    script {
                        remote.identityFile = "${sshKeyFile}"

                        listOfRemotes = [:]

                        puppet_agents_ips.each
                        {
                            def agent = it.toString()
                            def newremote = [:]
                            newremote.put("name" ,'ConfigAgent-' + agent)
                            newremote.put("allowAnyHosts",true)
                            newremote.put("user",remote.user)
                            newremote.put("identity",remote.identity)
                            newremote.put("password",remote.password)
                            newremote.put("host",agent)
                            newremote.put("identityFile", remote.identityFile)
                            listOfRemotes.put(agent, newremote)

                            jobs["run on $agent"] = {

                                echo "\nPuppet Agent IP --> " + agent
                                def tmp = listOfRemotes[agent]

                                def newRemoteSshObj = [:]
                                newRemoteSshObj.name = tmp["name"]
                                newRemoteSshObj.allowAnyHosts = tmp["allowAnyHosts"]
                                newRemoteSshObj.user = tmp["user"]
                                newRemoteSshObj.identity = tmp["identity"]
                                newRemoteSshObj.password = tmp["password"]
                                newRemoteSshObj.host = tmp["host"]
                                newRemoteSshObj.identityFile = tmp["identityFile"]

                                response = sshCommand remote:newRemoteSshObj, command: "swapoff -a", sudo: true
                                echo "Swap turned off on Agent --> " + agent

                                // Check if kubernetes cluster is already installed/running. If so, reset it with kubeadm.
                                response = sshCommand remote:newRemoteSshObj, command: "which kubeadm && echo \$? || echo \$?", sudo: true
                                temp = response?.split("\n")
                                if( temp != null && temp[temp.length - 1] == "0") {

                                    response = sshCommand remote:newRemoteSshObj, command: "kubeadm reset -f ", sudo: true
                                    echo "Reset kubeadm on Agent --> " + agent

                                    response = sshCommand remote:newRemoteSshObj, command: "rm -r -f /etc/cni/net.d", sudo: true
                                    response = sshCommand remote:newRemoteSshObj, failOnError: false, command: "yum remove -y docker* kube*", sudo: true
                                    echo "Removal of docker and kubernetes tools on Agent --> " + agent + " --> Done."

                                    isMaster = etcd_hosts_list.find{ it.toString().contains(agent)}
                                    if(isMaster)
                                    {
                                        // meaning, this agent is a master and have etcd running. So shutdown etcd.
                                        response = sshCommand remote:newRemoteSshObj, command: "systemctl stop etcd", sudo: true
                                        response = sshCommand remote:newRemoteSshObj, command: "systemctl disable etcd", sudo: true
                                        response = sshCommand remote:newRemoteSshObj, command: "rm -r -f /var/lib/etcd", sudo: true
                                        response = sshCommand remote:newRemoteSshObj, command: "rm /etc/systemd/system/etcd.service", sudo: true
                                        echo "Stopped and removed ETCD on Agent " + agent + "--> Done."

                                        response = sshCommand remote:newRemoteSshObj, command: "rm -r -f ~/.kube", sudo: false
                                        echo "Removal of .kube folder on Agent " + agent + "--> Done."

                                        // Ports: 10250 - Kubelet API, 6443 - Kubernetes API server, 2379-2380	etcd server client API, 8472 & 4240 Cilium ports
                                        response = sshCommand remote:newRemoteSshObj, command: "firewall-cmd --remove-port=2379/tcp --zone=public --permanent", sudo: true
                                        response = sshCommand remote:newRemoteSshObj, command: "firewall-cmd --remove-port=2380/tcp --zone=public --permanent", sudo: true
                                        response = sshCommand remote:newRemoteSshObj, command: "firewall-cmd --remove-port=6443/tcp --zone=public --permanent", sudo: true
                                        response = sshCommand remote:newRemoteSshObj, command: "firewall-cmd --remove-port=10250/tcp --zone=public --permanent", sudo: true
                                    }
                                }

                                response = sshCommand remote:newRemoteSshObj, failOnError: false, command: "firewall-cmd --remove-port=8472/udp --zone=public --permanent", sudo: true
                                response = sshCommand remote:newRemoteSshObj, failOnError: false, command: "firewall-cmd --remove-port=4240/tcp --zone=public --permanent", sudo: true
                                response = sshCommand remote:newRemoteSshObj, failOnError: false, command: "firewall-cmd --reload", sudo: true
                                response = sshCommand remote:newRemoteSshObj, failOnError: false, command: "firewall-cmd --list-all", sudo: true
                                echo "Reset Firewall rules on Agent " + agent + " --> Done."

                                // Now that we have "clean VM" from k8s perspective, run puppet agent to download catalog from master to install k8s.
                                //response = sshCommand remote:newRemoteSshObj, command: "ln -f -s /etc/puppetlabs/puppet/puppet.conf ~/.puppetlabs/etc/puppet/"
                                response = sshCommand remote:newRemoteSshObj, failOnError: false, command: "sudo -i puppet agent -t -d && echo \$? || echo \$?", sudo: false
                                temp = response?.split("\n")
                                if( temp == null || ( temp[temp.length - 1] != "0" && temp[temp.length - 1] != "2") ) {
                                    error("Puppet Agent has failed. See response.\n " + response)
                                }
                                echo "Run puppet agent on Agent " + agent + " --> Done."
                            }
                        }
                        parallel jobs
                    }
                }
            }
        }

        stage('Verify-Kubernetes-Installation') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: "jenkinsSshID", keyFileVariable: 'sshKeyFile')]){
                    script {
                        remote.identityFile = "${sshKeyFile}"

                        someMasterNode = etcd_hosts_list[0].split(":")[1]
                        def k8sMasterRemote = [:]
                        k8sMasterRemote.name = 'ConfigKubernetesMaster-' + someMasterNode
                        k8sMasterRemote.allowAnyHosts = true
                        k8sMasterRemote.user = remote.user
                        k8sMasterRemote.identity = remote.identity
                        k8sMasterRemote.password = remote.password
                        k8sMasterRemote.host = someMasterNode
                        k8sMasterRemote.identityFile = remote.identityFile

                        echo "Verifying if Kubernetes Cluster is running on all nodes..."
                        response = sshCommand remote:k8sMasterRemote, command: "mkdir -p ~/.kube", sudo: false
                        response = sshCommand remote:k8sMasterRemote, command: "cp /etc/kubernetes/admin.conf ~/.kube/config", sudo: true
                        response = sshCommand remote:k8sMasterRemote, command: "chown -R ${k8sMasterRemote.user}:${k8sMasterRemote.user} ~/.kube", sudo: true

                        // since .kube is a folder, it needs to have executable permissions so that kubectl can search.
                        response = sshCommand remote:k8sMasterRemote, command: "chmod -R +x ~/.kube", sudo: true
                        response = sshCommand remote:k8sMasterRemote, command: "kubectl get nodes", sudo: false
                        temp = response.split("\n")
                        if(temp == null || temp.size() != puppet_agents_ips.size() + 1 ) {
                            error("Failed to install Kubernetes on some puppet agents. See response.\n " + response)
                        }

                        // TODO: discuss if needed. sometimes workers are a bit slow in joining.
                        // for(int i = 1; i < temp.size(); i++)
                        // {
                        //     if(temp[i].contains("NotReady")) {
                        //         error("A kubernetes node " + temp[i] + " is found not ready.")
                        //     }
                        // }
                        echo "Response received from master node " + someMasterNode + " --> " + response
                    }
                }
            }
        }
   }
}
