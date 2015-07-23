#!/bin/bash
# vim: set sw=4 ts=4 et:

# Generate password via openssl rand -hex 10

# ------------------------------------------
# Set script info
# ------------------------------------------
#
# Base information
SCRIPT_NAME=$(basename $0)
SCRIPT_DIR=$(dirname $(readlink -f $0))
PARENT_DIR=$(dirname ${SCRIPT_DIR})

#
# Directory information
LIB_DIR="${PARENT_DIR}/lib"
ETC_DIR="${PARENT_DIR}/etc"
IMG_DIR="${PARENT_DIR}/images"
LIB_CONF_DIR="${LIB_DIR}/conf"

#
# Config files
PS_UTILS="${LIB_DIR}/ps_utils.sh"
SYS_CONF="${ETC_DIR}/system.conf"
PWD_CONF="${ETC_DIR}/cloud-passwords.conf"

ROLE_CONF="/etc/kilo-installer/node-role.conf"
# NODE_ROLE is imported at below

NIC_CONF="/etc/network/interfaces"
NTP_CONF="/etc/ntp.conf"

#
# Step-status
STATUS_STEP_2="/etc/kilo-installer/step-2"

# ------------------------------------------
# Source base functions
# ------------------------------------------
if [[ ! -e "${PS_UTILS}" ]]; then
    echo "Error: \"${PS_UTILS}\" is not found!"
    exit 1
fi 
source ${PS_UTILS}

log_info "\"${SCRIPT_NAME}\" started."

# ------------------------------------------
# Import pscloud-role.conf
# ------------------------------------------
if [[ ! -e "${ROLE_CONF}" ]]; then
    log_error "\"${ROLE_CONF}\" is not found!"
fi

#
# Set NODE_ROLE
NODE_ROLE=$(cat ${ROLE_CONF})
log_info "\"${ROLE_CONF}\" imported."

# ------------------------------------------
# Import system.conf
# ------------------------------------------
if [[ ! -e "${SYS_CONF}" ]]; then
    log_error "\"${SYS_CONF}\" is not found!"
fi 
source ${SYS_CONF}
log_info "\"${SYS_CONF}\" imported."

# ------------------------------------------
# Setup network
# ------------------------------------------
#
# clean up sources.list before actually started
validate_and_backup "/etc/apt/sources.list"
echo > /etc/apt/sources.list
apt-get -y update

#
# make sure vlan and ifenslave is installed
install_pkg vlan ifenslave
#
# Disable network-manager
stop network-manager
echo "manual"                       > /etc/init/network-manager.override
update-rc.d network-manager remove
log_info "network-manager is disabled."

#
# Set network adapter
validate_and_backup ${NIC_CONF}
log_info "\"${NIC_CONF}\" is validated and backed up"

#
# Stop all nic, ifdown -a
ifdown -a
log_info "all interfaces is shutdown."

#
# Configure interfaces
echo "# interfaces(5) file used by ifup(8) and ifdown(8)"  > ${NIC_CONF}
echo "auto lo"                                            >> ${NIC_CONF}
echo "iface lo inet loopback"                             >> ${NIC_CONF}
echo ""                                                   >> ${NIC_CONF}
echo "# Management Network interface"                     >> ${NIC_CONF}
echo "auto ${NIC_P1}"                                     >> ${NIC_CONF}
echo "iface ${NIC_P1} inet static"                        >> ${NIC_CONF}
echo "    address ${MGMT_IPADDR}"                         >> ${NIC_CONF}
echo "    netmask ${MGMT_NETMASK}"                        >> ${NIC_CONF}
echo "    gateway ${MGMT_GATEWAY}"                        >> ${NIC_CONF}
echo "    dns-nameservers ${MGMT_DNS1}"                   >> ${NIC_CONF}
echo "    dns-search ${MGMT_DOMAIN_NAME}"                 >> ${NIC_CONF}
echo ""                                                   >> ${NIC_CONF}
echo "# vSwitch Tunnel interface"                         >> ${NIC_CONF}
echo "auto ${NIC_P2}"                                     >> ${NIC_CONF}
echo "iface ${NIC_P2} inet static"                        >> ${NIC_CONF}
echo "    address ${INT_IPADDR}"                          >> ${NIC_CONF}
echo "    netmask ${INT_NETMASK}"                         >> ${NIC_CONF}
echo "    gateway ${INT_GATEWAY}"                         >> ${NIC_CONF}
echo "    dns-nameservers ${INT_DNS1}"                    >> ${NIC_CONF}
echo ""                                                   >> ${NIC_CONF}

#
# Setup external interface is only on Controller
if [[ "${NODE_ROLE}" = "controller" ]] || [[ "${NODE_ROLE}" = "allinone" ]]; then    
    echo "# External Network tag VLAN"                    >> ${NIC_CONF}
    echo "auto ${NIC_P2}.${VLANID_EXT}"                   >> ${NIC_CONF}
    echo "iface ${NIC_P2}.${VLANID_EXT} inet manual"      >> ${NIC_CONF}
    echo "    ovs_bridge br-ex"                           >> ${NIC_CONF}
    echo "    ovs_type OVSPort"                           >> ${NIC_CONF}
    echo ""                                               >> ${NIC_CONF}
    echo "auto br-ex"                                     >> ${NIC_CONF}          
    echo "allow-ovs br-ex"                                >> ${NIC_CONF}
    echo "iface br-ex inet static"                        >> ${NIC_CONF}
    echo "    ovs_type OVSBridge"                         >> ${NIC_CONF}
    echo "    ovs_ports ${NIC_P2}.${VLANID_EXT}"          >> ${NIC_CONF}
    echo "    address ${EXT_IPADDR}"                      >> ${NIC_CONF}
    echo "    netmask ${EXT_NETMASK}"                     >> ${NIC_CONF}
    echo "    gateway ${EXT_GATEWAY}"                     >> ${NIC_CONF}
    echo "    dns-nameservers ${EXT_DNS1}"                >> ${NIC_CONF}
fi

log_info "\"${NIC_CONF}\" is generated."

#
# Up all interfaces, ifup -a
ifup -a
log_info "all interfaces is up."

# ------------------------------------------
# Set sysctl.conf
# ------------------------------------------
SYSCTL="/etc/sysctl.conf"
validate_and_backup ${SYSCTL}
if [[ "${NODE_ROLE}" = "controller" ]] || [[ "${NODE_ROLE}" = "allinone" ]]; then 
    if [[ $(grep -i "net.ipv4.ip_forward=" ${SYSCTL} ) ]]; then
        sed "s/net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/"   -i ${SYSCTL}
    else
        echo "net.ipv4.ip_forward=1"                            >> ${SYSCTL}
    fi
fi
#
if [[ $(grep -i "net.ipv4.conf.all.rp_filter=" ${SYSCTL} ) ]]; then
    sed "s/net.ipv4.conf.all.rp_filter=.*/net.ipv4.conf.all.rp_filter=0/" -i ${SYSCTL}
else
    echo "net.ipv4.conf.all.rp_filter=0"                        >> ${SYSCTL}
fi
#
if [[ $(grep -i "net.ipv4.conf.default.rp_filter=" ${SYSCTL} ) ]]; then
    sed "s/net.ipv4.conf.default.rp_filter=.*/net.ipv4.conf.default.rp_filter=0/" -i ${SYSCTL}
else
    echo "net.ipv4.conf.default.rp_filter=0"                    >> ${SYSCTL}
fi

#
# Enable new configuration
sysctl -p

log_info "\"${SYSCTL}\" is configured."

# ------------------------------------------
# Set ntp server
# ------------------------------------------
validate_and_backup ${NTP_CONF}

sed "s/^server/#server/"                                  -i ${NTP_CONF}
#
if [[ "${NODE_ROLE}" = "controller" ]] || [[ "${NODE_ROLE}" = "allinone" ]]; then
    echo "server 127.127.1.0 stratum 2"                   >> ${NTP_CONF}
fi

if [[ "${NODE_ROLE}" = "compute" ]]; then
    #echo "server ${CONTR_MGMT_IP} stratum 2"             >> ${NTP_CONF}
    echo "server ${CONTR_MGMT_IP}"                        >> ${NTP_CONF}
fi

log_info "NTP server is configured"
service ntp restart

# ------------------------------------------
# Setup /etc/hostname and /etc/hosts
# ------------------------------------------
validate_and_backup "/etc/hosts"

if [[ "${NODE_ROLE}" = "controller" ]] || [[ "${NODE_ROLE}" = "allinone" ]]; then
    echo "${CONTR_HOSTNAME}"                             > /etc/hostname
    # Setup /etc/hosts
    echo "127.0.0.1 localhost"                              > /etc/hosts
    echo ""                                                >> /etc/hosts
    echo "# for IPv6 capable hosts"                        >> /etc/hosts
    echo "::1     ip6-localhost ip6-loopback"              >> /etc/hosts
    echo "fe00::0 ip6-localnet"                            >> /etc/hosts
    echo "ff00::0 ip6-mcastprefix"                         >> /etc/hosts
    echo "ff02::1 ip6-allnodes"                            >> /etc/hosts
    echo "ff02::2 ip6-allrouters"                          >> /etc/hosts
    echo ""                                                >> /etc/hosts
    echo "# for openstack"                                 >> /etc/hosts
    echo "${MGMT_IPADDR}  ${CONTROLLER_MGMT_FQDN}  ${CONTR_HOSTNAME}"\
                                                           >> /etc/hosts
    echo "${EXT_IPADDR}  ${CONTROLLER_EXT_FQDN}  ${CONTR_HOSTNAME}"\
                                                           >> /etc/hosts
fi

if [[ "${NODE_ROLE}" = "compute" ]]; then
    echo "${COMPT_HOSTNAME}"                             > /etc/hostname
    # Get /etc/hosts from Controller node
    scp -r -o StrictHostKeyChecking=no  \
                            root@${CONTR_MGMT_IP}:/etc/hosts  /etc/hosts
    # Add hostname
    echo "${MGMT_IPADDR}  ${COMPT_HOSTNAME}.${MGMT_DOMAIN_NAME}\
      ${COMPT_HOSTNAME}"                                   >> /etc/hosts
    # Put new /etc/hosts to Controller node
    scp -r -o StrictHostKeyChecking=no  \
                            /etc/hosts  root@${CONTR_MGMT_IP}:/etc/hosts
fi
# ------------------------------------------
# destroy default virbr0
# ------------------------------------------
virsh net-destroy default
virsh net-undefine default

# ------------------------------------------
# set finish flag
# ------------------------------------------
echo "finished" > ${STATUS_STEP_2}

# ------------------------------------------
# reboot system
# ------------------------------------------
reboot
# init 6
log_info "System will reboot before setup openstack"

#
log_info "\"${SCRIPT_NAME}\" finished."
#