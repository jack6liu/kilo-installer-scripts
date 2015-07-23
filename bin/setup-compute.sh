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

#
# Sample files
NOVA_CONF_SAMPLE="${LIB_CONF_DIR}/nova/nova.conf.sample"
NEUTRON_CONF_SAMPLE="${LIB_CONF_DIR}/neutron/neutron.conf.sample"
NEUTRON_ML2_SAMPLE="${LIB_CONF_DIR}/neutron/plugins/ml2/ml2_conf.ini.sample"

#
# Step-status
STATUS_STEP_4="/etc/kilo-installer/step-4"

# ------------------------------------------
# Source base functions
# ------------------------------------------
if [[ ! -e "${PS_UTILS}" ]]; then
    echo "Error: \"${PS_UTILS}\" is not found!"
    exit 1
fi 
source ${PS_UTILS}
log_info "\"${SCRIPT_NAME}\" started."

#
# ------------------------------------------
# Import system.conf
# ------------------------------------------
if [[ ! -e "${SYS_CONF}" ]]; then
    log_error "\"${SYS_CONF}\" is not found!"
fi 
source ${SYS_CONF}
log_info "\"${SYS_CONF}\" imported."

# ------------------------------------------
# Source cloud-passwords.conf
# ------------------------------------------
if [[ ! -e "${PWD_CONF}" ]]; then
    log_error "\"${PWD_CONF}\" is not found!"
fi 
source ${PWD_CONF}
log_info "\"${PWD_CONF}\" is imported."

# ------------------------------------------
# Setup nova-compute
# ------------------------------------------
#
# Install nova-compute packages
install_pkg nova-compute sysfsutils libguestfs-tools python-guestfs

# Export token
export OS_SERVICE_TOKEN=${ADMIN_TOKEN}
export OS_SERVICE_ENDPOINT=http://${CONTROLLER_MGMT_FQDN}:35357/v2.0

#
# Create nova.conf
validate_and_backup "/etc/nova/nova.conf"
SERVICE_TENANT_ID=$(keystone tenant-list | awk '/ service / {print $2}')

sed -e "s/%NOVA_DB_PWD%/${NOVA_DB_PWD}/"                             \
    -e "s/%CONTROLLER_MGMT_FQDN%/${CONTROLLER_MGMT_FQDN}/"           \
    -e "s/%NOVA_PWD%/${NOVA_PWD}/"                                   \
    -e "s/%RABBIT_PWD%/${RABBIT_PWD}/"                               \
    -e "s/%MY_IPADDR%/${MGMT_IPADDR}/"                               \
    -e "s/%NEUTRON_PWD%/${NEUTRON_PWD}/"                             \
    -e "s/%SERVICE_TENANT_ID%/${SERVICE_TENANT_ID}/"                 \
    -e "s/%META_SHARED_SECRET%/${META_SHARED_SECRET}/"               \
                                ${NOVA_CONF_SAMPLE} > /etc/nova/nova.conf
log_info "nova.conf is created."

#
# Fix permission
fix_service_permission "nova"

#
# Remove SQLite
rm -f /var/lib/nova/nova.sqlite
log_info "SQLite database is removed."

#
# Restart service
service nova-compute restart

#
# setup neutron.conf
#
# Create neutron.conf
validate_and_backup "/etc/neutron/neutron.conf"

SERVICE_TENANT_ID=$(keystone tenant-list | awk '/ service / {print $2}')
sed -e "s/%NEUTRON_DB_PWD%/${NEUTRON_DB_PWD}/"                       \
    -e "s/%CONTROLLER_MGMT_FQDN%/${CONTROLLER_MGMT_FQDN}/"           \
    -e "s/%NEUTRON_PWD%/${NEUTRON_PWD}/"                             \
    -e "s/%RABBIT_PWD%/${RABBIT_PWD}/"                               \
    -e "s/%SERVICE_TENANT_ID%/${SERVICE_TENANT_ID}/"                 \
    -e "s/%NOVA_PWD%/${NOVA_PWD}/"                                   \
                       ${NEUTRON_CONF_SAMPLE} > /etc/neutron/neutron.conf
log_info "neutron.conf is created."

#
# Create plugins/ml2/ml2_conf.ini
validate_and_backup "/etc/neutron/plugins/ml2/ml2_conf.ini"

sed -e "s/%MY_TUNNEL_IP%/${INT_IPADDR}/"  \
            ${NEUTRON_ML2_SAMPLE} > /etc/neutron/plugins/ml2/ml2_conf.ini

log_info "ml2_conf.ini is created."

#
# setup ovs
ovs-vsctl add-br br-int

log_info "openvswitch is configured."

#
# restart neutron
for SVC in nova-compute openvswitch-switch \
           neutron-plugin-openvswitch-agent; do
    service $SVC restart
done

# ------------------------------------------
# set finish flag
# ------------------------------------------
echo "finished" > ${STATUS_STEP_4}

#
log_info "\"${SCRIPT_NAME}\" finished."
#