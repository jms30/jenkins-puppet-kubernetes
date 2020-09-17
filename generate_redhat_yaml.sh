#!/usr/bin/env bash
 
###########################################################################################
#                                                                                         #
#       					RUN ON MASTER WITH SUDO PRIVILEDGES.                     	  #
#                                                                                         #
# THIS SCRIPT WILL RUN A DOCKER IMAGE FOR PUPPETLABS/KUBETOOL THAT WILL GENERATE OS       #
# SPECIFIC YAML FILE (RedHat.yaml) IN /etc/puppetlabs/code/environments/production/data   #
# DIRECTORY. THE YAML FILE WILL BE USED AS INPUT IN INSTALLING THE PUPPETLABS/KUBERNETES  #
# MODULE ON AGENTS.                                                                       #
#                                                                                         #
###########################################################################################

set -xe 
 
##################### VARIABLES #######################
 
OS=RedHat       ## PLEASE MIND THE CASE SENSITIVITY.
 
ETCD_VERSION=#{etcd_version}#							#### default 3.4.8
DOCKER_CE_VERSION=#{docker_version}#					#### default 18.06.1.ce-3.el7
KUBETOOL_VERSION=#{kubetool_version}#					#### default 5.1.0
KUBERNETES_VERSION=#{kubernetes_version}#				#### default 1.18.0
CNI_PROVIDER_VERSION=#{cilium_version}#					#### default 1.7
ETCD_DEFAULT_CLUSTER=#{etcd_hosts}# 					#### ASSUME THAT YOU HAVE PASSED COMMA-SEPARATED
														#### LIST OF hostname:ipaddress FOR ETCD HOSTS.

MANAGE_DOCKER="${MANAGE_DOCKER:-true}"

DESTINATION_DIRECTORY=/etc/puppetlabs/code/environments/production/

#####################################################################################################
#																									#
#    If the provided list of ETCD Hosts contains Fully qualified hostnames then we need to 			#
#    take out the domain part from that. This is necessary due to ETCD's internal implementation.	# 
#    Here, we split down the domain name, but remember that for later useage. The Kubetool			#
#    will actually use that scrapped hostname (without domain name) in generating ETCD specific		#
#    certificate and key file (<hostname>.yaml). This file needs to be renamed so that the			# 
#    agent(who looks for the file with its FQDN name) can find it on master.						# 
#																									#
#####################################################################################################

ETCD_HOSTS_WITH_FQDN_ARR=()
ETCD_HOSTS_ARR=()

ALL_ETCD_HOSTS_ARR=($( echo $ETCD_DEFAULT_CLUSTER | tr "," " " ))			#### Split the list on comma

for host in ${ALL_ETCD_HOSTS_ARR[@]}
do  
    HOST_AND_IP_PART=($(echo $host | tr ":" " "))							#### Split each item into host and ip part.
    HOST_PART=${HOST_AND_IP_PART[0]}
    IP_PART=${HOST_AND_IP_PART[1]}
    ALL_PARTS_OF_HOST_PART=($(echo $HOST_PART | tr "." " "))				#### Split the host part on dot to see if this is FQDN or not.
    if [[ ${#ALL_PARTS_OF_HOST_PART[@]} -gt 1 ]];
    then
        ETCD_HOSTS_WITH_FQDN_ARR+=$HOST_PART								#### This item's host part is an FQDN. Scrap down the domain part for the sake of ETCD.
        ETCD_HOSTS_ARR+=(${ALL_PARTS_OF_HOST_PART[0]}:$IP_PART)				#### Re-write the host+ip part with non-FQDN hostname and IP
    else
        ETCD_HOSTS_ARR+=($host)												#### This item's host part is already non-FQDN. No further action needed.
    fi
done  

ETCD_HOSTS=$(IFS=, ; echo "${ETCD_HOSTS_ARR[*]}") 							#### Re-create the list with comma separation to pass to kubetool.

mkdir -p $DESTINATION_DIRECTORY/data
cd $DESTINATION_DIRECTORY

rm -r -f data/* 
mkdir -p data/nodes


${CONTAINER_CLI:-docker} run --rm \
-v $(pwd):/mnt:Z \
-e OS=${OS} \
-e VERSION=${KUBERNETES_VERSION} \
-e CONTAINER_RUNTIME=docker \
-e CNI_PROVIDER=cilium \
-e CNI_PROVIDER_VERSION=1.4.3 \
-e ETCD_INITIAL_CLUSTER=${ETCD_HOSTS} \
-e ETCD_IP="%{networking.ip}" \
-e KUBE_API_ADVERTISE_ADDRESS="%{networking.ip}" \
-e INSTALL_DASHBOARD=true puppet/kubetool:${KUBETOOL_VERSION}
 
mv Redhat.yaml ${OS}.yaml
 
sed -i -e "s/1.18\/cilium/quick-install/g" ${OS}.yaml
sed -i -e "s/1.4.3\/examples/v${CNI_PROVIDER_VERSION}\/install/g" ${OS}.yaml
 
sed -i "17i kubernetes::etcd_version: ${ETCD_VERSION}" ${OS}.yaml
sed -i "18i kubernetes::etcd_archive: etcd-v${ETCD_VERSION}-linux-amd64.tar.gz" ${OS}.yaml
sed -i "19i kubernetes::etcd_source: https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz" ${OS}.yaml
 
sed -i "20i kubernetes::containerd_version: ${CONTAINERD_VERSION}" ${OS}.yaml
 
sed -i "21i kubernetes::manage_docker: ${MANAGE_DOCKER}" ${OS}.yaml
sed -i "22i kubernetes::docker_yum_baseurl: https://download.docker.com/linux/centos/7/x86_64/stable/" ${OS}.yaml
sed -i "23i kubernetes::docker_yum_gpgkey: https://download.docker.com/linux/centos/gpg" ${OS}.yaml
sed -i "24i kubernetes::docker_package_name: docker-ce" ${OS}.yaml
sed -i "25i kubernetes::docker_version: ${DOCKER_CE_VERSION}" ${OS}.yaml
 
mv ${OS}.yaml data/
mv hiera.yaml hiera.yaml.bak
mv *.yaml data/nodes
mv hiera.yaml.bak hiera.yaml


cd data/nodes										#### Rename the files with FQDN hostnames so that agents can find them.
for host in ${ETCD_HOSTS_WITH_FQDN_ARR[@]}
do
HOST_PART=($( echo $host | tr "." " "))				
HOST_PART_YAML_FILENAME=${HOST_PART[0]}.yaml		#### See if yaml file's name is generated from the scrapped down FQDN name?
if [[ -f $HOST_PART_YAML_FILENAME ]];
then			
	mv ${HOST_PART_YAML_FILENAME} ${host}.yaml		#### If such file was generated, then rename it with the original FQDN name.
fi
done

