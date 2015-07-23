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
KEYSTONE_CONF_SAMPLE="${LIB_CONF_DIR}/keystone/keystone.conf.sample"
GLANCE_API_SAMPLE="${LIB_CONF_DIR}/glance/glance-api.conf.sample"
GLANCE_REG_SAMPLE="${LIB_CONF_DIR}/glance/glance-registry.conf.sample"
GLANCE_CACHE_SAMPLE="${LIB_CONF_DIR}/glance/glance-cache.conf.sample"
GLANCE_MANAGE_SAMPLE="${LIB_CONF_DIR}/glance/glance-manage.conf.sample"
GLANCE_SCRUBBER_SAMPLE="${LIB_CONF_DIR}/glance/glance-scrubber.conf.sample"
GLANCE_SEARCH_SAMPLE="${LIB_CONF_DIR}/glance/glance-search.conf.sample"
NOVA_CONF_SAMPLE="${LIB_CONF_DIR}/nova/nova.conf.sample"
NEUTRON_CONF_SAMPLE="${LIB_CONF_DIR}/neutron/neutron.conf.sample"
NEUTRON_ML2_SAMPLE="${LIB_CONF_DIR}/neutron/plugins/ml2/ml2_conf.ini.sample"
NEUTRON_L3_SAMPLE="${LIB_CONF_DIR}/neutron/l3_agent.ini.sample"
NEUTRON_DHCP_SAMPLE="${LIB_CONF_DIR}/neutron/dhcp_agent.ini.sample"
NEUTRON_DNSMASQ_SAMPLE="${LIB_CONF_DIR}/neutron/dnsmasq-neutron.conf.sample"
NEUTRON_META_SAMPLE="${LIB_CONF_DIR}/neutron/metadata_agent.ini.sample"
CINDER_CONF_SAMPLE="${LIB_CONF_DIR}/cinder/cinder.conf.sample"

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

#
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
# Keystone setup
# ------------------------------------------
# Install Keystone packages
install_pkg keystone python-openstackclient memcached python-memcache

# Create database for keystone
create_service_db "${DB_PWD}" "keystone" "${KEYSTONE_DB_PWD}"
log_info "database for keystone is created."

#
# Setup keystone.conf
validate_and_backup "/etc/keystone/keystone.conf"

sed -e "s/%ADMIN_TOKEN%/${ADMIN_TOKEN}/"                     \
    -e "s/%KEYSTONE_DB_PWD%/${KEYSTONE_DB_PWD}/"             \
    -e "s/%CONTROLLER_MGMT_FQDN%/${CONTROLLER_MGMT_FQDN}/"   \
    -e "s/%RABBIT_PWD%/${RABBIT_PWD}/"                       \
                               ${KEYSTONE_CONF_SAMPLE} > /etc/keystone/keystone.conf
log_info "keystone.conf is created."

#
# Populate keystone database
su -s /bin/sh -c "keystone-manage db_sync" keystone
log_info "keystone database is populated."

#
# Fix permissions
fix_service_permission "keystone"

#
# Restart keystone service
service keystone restart

#
# Remove SQLite
rm -f /var/lib/keystone/keystone.db
log_info "SQLite database is removed."

#
# Purge expired token
(crontab -l -u keystone 2>&1 | grep -q token_flush) ||  \
echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' \
 >> /var/spool/cron/crontabs/keystone
log_info "Token flush cron job is created."
# ------------------------------------------
# Keystone initialization
# ------------------------------------------
# Export token
export OS_SERVICE_TOKEN=${ADMIN_TOKEN}
export OS_SERVICE_ENDPOINT=http://${CONTROLLER_MGMT_FQDN}:35357/v2.0

log_info "sleep serveral seconds for keystone service ready."
sleep 10

#
# Create admin tenants, user and admin role
keystone tenant-create --name=admin --description "Admin Tenant"
keystone user-create --name admin --pass ${ADMIN_PWD}  \
                     --email admin@openstack.local
keystone role-create --name admin
keystone user-role-add --user admin --tenant admin --role admin

log_info "admin user is created."

#
# Create demo tenant, user and _member_ role
keystone tenant-create --name demo --description "Demo Tenant"
keystone user-create --name demo --tenant demo --pass ${DEMO_PWD}  \
                     --email demo@openstack.local

log_info "demo user is created."

#
# Create service tenant
keystone tenant-create --name service --description "Service Tenant"

log_info "service tenant is created."

#
# Create endpoints
keystone service-create --name keystone --type identity  \
  --description "OpenStack Identity"

keystone endpoint-create                                                 \
  --service-id $(keystone service-list | awk '/ identity / {print $2}')  \
  --publicurl http://${CONTROLLER_EXT_FQDN}:5000/v2.0                    \
  --internalurl http://${CONTROLLER_MGMT_FQDN}:5000/v2.0                 \
  --adminurl http://${CONTROLLER_MGMT_FQDN}:35357/v2.0                   \
  --region regionOne

log_info "keystone endpoints is created."

#
# Generate stackrc file
# for admin
echo "export OS_PROJECT_DOMAIN_ID=default"                    > /root/adminrc
echo "export OS_USER_DOMAIN_ID=default"                      >> /root/adminrc
echo "export OS_PROJECT_NAME=admin"                          >> /root/adminrc
echo "export OS_TENANT_NAME=admin"                           >> /root/adminrc
echo "export OS_USERNAME=admin"                              >> /root/adminrc
echo "export OS_PASSWORD=${ADMIN_PWD}"                       >> /root/adminrc
echo "export OS_AUTH_URL=http://${CONTROLLER_MGMT_FQDN}:35357/v3" \
                                                             >> /root/adminrc
log_info "adminrc is created."

#
# for demo
echo "export OS_PROJECT_DOMAIN_ID=default"                     > /root/demorc
echo "export OS_USER_DOMAIN_ID=default"                       >> /root/demorc
echo "export OS_PROJECT_NAME=demo"                            >> /root/demorc
echo "export OS_TENANT_NAME=demo"                             >> /root/demorc
echo "export OS_USERNAME=demo"                                >> /root/demorc
echo "export OS_PASSWORD=${DEMO_PWD}"                         >> /root/demorc
echo "export OS_AUTH_URL=http://${CONTROLLER_MGMT_FQDN}:35357/v3" \
                                                              >> /root/demorc
log_info "demorc is created."

# ------------------------------------------
# Glance setup
# ------------------------------------------
# Install Glance packages
install_pkg glance python-glanceclient

# Create database for glance
create_service_db "${DB_PWD}" "glance" "${GLANCE_DB_PWD}"
log_info "database for glance is created."

#
# Create service users
keystone user-create --name glance --pass ${GLANCE_PWD}
keystone user-role-add --user glance --tenant service --role admin

log_info "glance user is created."

#
# Create endpoint
keystone service-create --name glance --type image   \
  --description "OpenStack Image Service"

keystone endpoint-create                                             \
  --service-id $(keystone service-list | awk '/ image / {print $2}') \
  --publicurl http://${CONTROLLER_EXT_FQDN}:9292                     \
  --internalurl http://${CONTROLLER_MGMT_FQDN}:9292                  \
  --adminurl http://${CONTROLLER_MGMT_FQDN}:9292                     \
  --region regionOne

log_info "glance endpoint is created."

#
# Create glance-api.conf
validate_and_backup "/etc/glance/glance-api.conf"

sed -e "s/%GLANCE_DB_PWD%/${GLANCE_DB_PWD}/"                \
    -e "s/%CONTROLLER_MGMT_FQDN%/${CONTROLLER_MGMT_FQDN}/"  \
    -e "s/%GLANCE_PWD%/${GLANCE_PWD}/"                      \
    -e "s/%RABBIT_PWD%/${RABBIT_PWD}/"                      \
                           ${GLANCE_API_SAMPLE} > /etc/glance/glance-api.conf
log_info "glance-api.conf is created."

#
# Create glance-registry.conf
validate_and_backup "/etc/glance/glance-registry.conf"

sed -e "s/%GLANCE_DB_PWD%/${GLANCE_DB_PWD}/"                \
    -e "s/%CONTROLLER_MGMT_FQDN%/${CONTROLLER_MGMT_FQDN}/"  \
    -e "s/%GLANCE_PWD%/${GLANCE_PWD}/"                      \
    -e "s/%RABBIT_PWD%/${RABBIT_PWD}/"                      \
                      ${GLANCE_REG_SAMPLE} > /etc/glance/glance-registry.conf
log_info "glance-registry.conf is created."

#
# Create glance-cache.conf
validate_and_backup "/etc/glance/glance-cache.conf"
sed -e "s/%GLANCE_DB_PWD%/${GLANCE_DB_PWD}/"                \
    -e "s/%CONTROLLER_MGMT_FQDN%/${CONTROLLER_MGMT_FQDN}/"  \
    -e "s/%GLANCE_PWD%/${GLANCE_PWD}/"                      \
    -e "s/%RABBIT_PWD%/${RABBIT_PWD}/"                      \
                       ${GLANCE_CACHE_SAMPLE} > /etc/glance/glance-cache.conf
log_info "glance-cache.conf is created."

#
# Create glance-manage.conf
validate_and_backup "/etc/glance/glance-manage.conf"
sed -e "s/%GLANCE_DB_PWD%/${GLANCE_DB_PWD}/"                \
    -e "s/%CONTROLLER_MGMT_FQDN%/${CONTROLLER_MGMT_FQDN}/"  \
    -e "s/%GLANCE_PWD%/${GLANCE_PWD}/"                      \
    -e "s/%RABBIT_PWD%/${RABBIT_PWD}/"                      \
                     ${GLANCE_MANAGE_SAMPLE} > /etc/glance/glance-manage.conf
log_info "glance-manage.conf is created."

#
# Create glance-scrubber.conf
validate_and_backup "/etc/glance/glance-scrubber.conf"
sed -e "s/%GLANCE_DB_PWD%/${GLANCE_DB_PWD}/"                \
    -e "s/%CONTROLLER_MGMT_FQDN%/${CONTROLLER_MGMT_FQDN}/"  \
    -e "s/%GLANCE_PWD%/${GLANCE_PWD}/"                      \
    -e "s/%RABBIT_PWD%/${RABBIT_PWD}/"                      \
                 ${GLANCE_SCRUBBER_SAMPLE} > /etc/glance/glance-scrubber.conf
log_info "glance-scrubber.conf is created."

#
# Create glance-search.conf
validate_and_backup "/etc/glance/glance-search.conf"
sed -e "s/%GLANCE_DB_PWD%/${GLANCE_DB_PWD}/"                \
    -e "s/%CONTROLLER_MGMT_FQDN%/${CONTROLLER_MGMT_FQDN}/"  \
    -e "s/%GLANCE_PWD%/${GLANCE_PWD}/"                      \
    -e "s/%RABBIT_PWD%/${RABBIT_PWD}/"                      \
                     ${GLANCE_SEARCH_SAMPLE} > /etc/glance/glance-search.conf
log_info "glance-search.conf is created."

#
# Populate database
su -s /bin/sh -c "glance-manage db_sync" glance
log_info "glance database is created."

#
# Fix permission
fix_service_permission "glance"

#
# Restart service
for SVC in glance-registry glance-api; do
    service $SVC restart
done

#
# Remove SQLite
rm -f /var/lib/glance/glance.sqlite
log_info "SQLite database is removed."

# ------------------------------------------
# Nova controller setup
# ------------------------------------------
#
# Install nova package for controller
install_pkg nova-api nova-cert nova-conductor nova-consoleauth   \
            nova-novncproxy nova-scheduler python-novaclient

# Create database for nova
create_service_db "${DB_PWD}" "nova" "${NOVA_DB_PWD}"
log_info "database for nova is created."

#
# Create service users
keystone user-create --name nova --pass ${NOVA_PWD}
keystone user-role-add --user nova --tenant service --role admin

log_info "nova user is created."

#
# Create endpoint
keystone service-create --name nova --type compute    \
  --description "OpenStack Compute"

keystone endpoint-create                                               \
  --service-id $(keystone service-list | awk '/ compute / {print $2}') \
  --publicurl http://${CONTROLLER_EXT_FQDN}:8774/v2/%\(tenant_id\)s    \
  --internalurl http://${CONTROLLER_MGMT_FQDN}:8774/v2/%\(tenant_id\)s \
  --adminurl http://${CONTROLLER_MGMT_FQDN}:8774/v2/%\(tenant_id\)s    \
  --region regionOne

log_info "nova endpoint is created."

#
# Create nova.conf
validate_and_backup "/etc/nova/nova.conf"
SERVICE_TENANT_ID=$(keystone tenant-list | awk '/ service / {print $2}')

sed -e "s/%NOVA_DB_PWD%/${NOVA_DB_PWD}/"                   \
    -e "s/%CONTROLLER_MGMT_FQDN%/${CONTROLLER_MGMT_FQDN}/" \
    -e "s/%NOVA_PWD%/${NOVA_PWD}/"                         \
    -e "s/%RABBIT_PWD%/${RABBIT_PWD}/"                     \
    -e "s/%MY_IPADDR%/${MGMT_IPADDR}/"                     \
    -e "s/%NEUTRON_PWD%/${NEUTRON_PWD}/"                   \
    -e "s/%SERVICE_TENANT_ID%/${SERVICE_TENANT_ID}/"       \
    -e "s/%META_SHARED_SECRET%/${META_SHARED_SECRET}/"     \
                               ${NOVA_CONF_SAMPLE} > /etc/nova/nova.conf
log_info "nova.conf is created."

#
# Populate database
su -s /bin/sh -c "nova-manage db sync" nova
log_info "nova database is created."

#
# Fix permission
fix_service_permission "nova"

#
# Restart service
for SVC in nova-api nova-cert nova-consoleauth nova-scheduler \
           nova-conductor nova-novncproxy; do
    service $SVC restart
done

#
# Remove SQLite
rm -f /var/lib/nova/nova.sqlite
log_info "SQLite database is removed."


# ------------------------------------------
# Neutron controller and network node setup
# ------------------------------------------
#
# Install Neutron packages for controller
install_pkg neutron-server neutron-plugin-ml2 python-neutronclient \
            neutron-plugin-openvswitch-agent neutron-l3-agent      \
            neutron-dhcp-agent neutron-metadata-agent

# Create database for neutron
create_service_db "${DB_PWD}" "neutron" "${NEUTRON_DB_PWD}"
log_info "database for neutron is created."

#
# Create service users
keystone user-create --name neutron --pass ${NEUTRON_PWD}
keystone user-role-add --user neutron --tenant service --role admin

log_info "neutron user is created."

#
# Create endpoint
keystone service-create --name neutron --type network  \
  --description "OpenStack Networking"

keystone endpoint-create                                                \
  --service-id $(keystone service-list | awk '/ network / {print $2}')  \
  --publicurl http://${CONTROLLER_EXT_FQDN}:9696                        \
  --adminurl http://${CONTROLLER_MGMT_FQDN}:9696                        \
  --internalurl http://${CONTROLLER_MGMT_FQDN}:9696                     \
  --region regionOne

log_info "neutron endpoint is created."

#
# Create neutron.conf
validate_and_backup "/etc/neutron/neutron.conf"

SERVICE_TENANT_ID=$(keystone tenant-list | awk '/ service / {print $2}')
sed -e "s/%NEUTRON_DB_PWD%/${NEUTRON_DB_PWD}/"              \
    -e "s/%CONTROLLER_MGMT_FQDN%/${CONTROLLER_MGMT_FQDN}/"  \
    -e "s/%NEUTRON_PWD%/${NEUTRON_PWD}/"                    \
    -e "s/%RABBIT_PWD%/${RABBIT_PWD}/"                      \
    -e "s/%SERVICE_TENANT_ID%/${SERVICE_TENANT_ID}/"        \
    -e "s/%NOVA_PWD%/${NOVA_PWD}/"                          \
                           ${NEUTRON_CONF_SAMPLE} > /etc/neutron/neutron.conf
log_info "neutron.conf is created."

#
# Create plugins/ml2/ml2_conf.ini
validate_and_backup "/etc/neutron/plugins/ml2/ml2_conf.ini"

sed -e "s/%MY_TUNNEL_IP%/${INT_IPADDR}/"   \
                ${NEUTRON_ML2_SAMPLE} > /etc/neutron/plugins/ml2/ml2_conf.ini

log_info "ml2_conf.ini is created."

#
# Update nova.conf
#     -- Added to create nova.conf
#

#
# Create l3_agent.ini
validate_and_backup "/etc/neutron/l3_agent.ini"

cp -f ${NEUTRON_L3_SAMPLE} /etc/neutron/l3_agent.ini

log_info "l3_agent.ini is created."

#
# Create dhcp_agent.ini
validate_and_backup "/etc/neutron/dhcp_agent.ini"

cp -f ${NEUTRON_DHCP_SAMPLE} /etc/neutron/dhcp_agent.ini

log_info "dhcp_agent.ini is created."

#
# Create dnsmasq-neutron.conf
validate_and_backup "/etc/neutron/dnsmasq-neutron.conf"

cp -f ${NEUTRON_DNSMASQ_SAMPLE} /etc/neutron/dnsmasq-neutron.conf

log_info "dnsmasq-neutron.conf is created."

#
# Create metadata_agent.ini
validate_and_backup "/etc/neutron/metadata_agent.ini"

sed -e "s/%CONTROLLER_MGMT_FQDN%/${CONTROLLER_MGMT_FQDN}/"    \
    -e "s/%NEUTRON_PWD%/${NEUTRON_PWD}/"                      \
    -e "s/%META_SHARED_SECRET%/${META_SHARED_SECRET}/"        \
                     ${NEUTRON_META_SAMPLE} > /etc/neutron/metadata_agent.ini

log_info "metadata_agent.ini is created."

# Populate database
su -s /bin/sh -c "neutron-db-manage                                     \
                    --config-file /etc/neutron/neutron.conf             \
                    --config-file /etc/neutron/plugins/ml2/ml2_conf.ini \
                    upgrade head" neutron
log_info "neutron database is created."

#
# Fix permission
fix_service_permission "neutron"

#
# Setup OVS -- move to setup-system.sh
service openvswitch-switch restart
ovs-vsctl add-br br-int
ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex ${BOND_EXT}

# flush ip of ${BOND_EXT}
# add ip to br-ex
# ethtool -K ${BOND_EXT} gro off

#
# Restart service
for SVC in nova-api nova-scheduler nova-conductor           \
           neutron-server neutron-plugin-openvswitch-agent  \
           neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent; do
    service $SVC restart
done

#
# Remove SQLite
rm -f /var/lib/neutron/neutron.sqlite
log_info "SQLite database is removed."

# ------------------------------------------
# Setup cinder
# ------------------------------------------
# Install Cinder packages
install_pkg cinder-api cinder-scheduler python-cinderclient  \
            lvm2 qemu cinder-volume

# Create database for cinder
create_service_db "${DB_PWD}" "cinder" "${CINDER_DB_PWD}"
log_info "database for cinder is created."

#
# Create service users
keystone user-create --name cinder --pass ${CINDER_PWD}
keystone user-role-add --user cinder --tenant service --role admin

log_info "cinder user is created."

#
# Create endpoint v1
keystone service-create --name=cinder --type=volume  \
  --description="OpenStack Block Storage"

keystone endpoint-create                                                \
  --service-id=$(keystone service-list | awk '/ volume / {print $2}')   \
  --publicurl=http://${CONTROLLER_EXT_FQDN}:8776/v1/%\(tenant_id\)s     \
  --internalurl=http://${CONTROLLER_MGMT_FQDN}:8776/v1/%\(tenant_id\)s  \
  --adminurl=http://${CONTROLLER_MGMT_FQDN}:8776/v1/%\(tenant_id\)s     \
  --region regionOne

log_info "cinder v1 endpoint is created."

#
# Create endpoint v2
keystone service-create --name=cinderv2 --type=volumev2  \
  --description="OpenStack Block Storage v2"

keystone endpoint-create                                                \
  --service-id=$(keystone service-list | awk '/ volumev2 / {print $2}') \
  --publicurl=http://${CONTROLLER_EXT_FQDN}:8776/v2/%\(tenant_id\)s     \
  --internalurl=http://${CONTROLLER_MGMT_FQDN}:8776/v2/%\(tenant_id\)s  \
  --adminurl=http://${CONTROLLER_MGMT_FQDN}:8776/v2/%\(tenant_id\)s     \
  --region regionOne

log_info "cinder v2 endpoint is created."

#
# Create cinder.conf
validate_and_backup "/etc/cinder/cinder.conf"

sed -e "s/%CINDER_DB_PWD%/${CINDER_DB_PWD}/"                            \
    -e "s/%CONTROLLER_MGMT_FQDN%/${CONTROLLER_MGMT_FQDN}/"              \
    -e "s/%CINDER_PWD%/${CINDER_PWD}/"                                  \
    -e "s/%RABBIT_PWD%/${RABBIT_PWD}/"                                  \
    -e "s/%MY_IPADDR%/${MGMT_IPADDR}/"                                  \
                              ${CINDER_CONF_SAMPLE} > /etc/cinder/cinder.conf
log_info "glance-registry.conf is created."

#
# Populate database
su -s /bin/sh -c "cinder-manage db sync" cinder
log_info "cinder database is created."

#
# Fix permission
fix_service_permission "cinder"

#
# Set cinder volume-group
# If it is a local loop device
if [[ "${CINDER_VG_DEVICE}" = "loop" ]]; then
    # Create loop device for initial cinder backend
    # truncate -s 50g /var/lib/cinder/vg-cinder-50g
    CINDER_VG_SIZE_GB=${CINDER_VG_SIZE_GB:-5}
    log_info "cinder volume-group ${CINDER_VG_SIZE_GB}GB loop device."
    CINDER_VG_FILE="/var/lib/cinder/vg-cinder-${CINDER_VG_SIZE_GB}g"
    CINDER_LOOP_DEVICE="/dev/loop5"
    fallocate -l ${CINDER_VG_SIZE_GB}g  ${CINDER_VG_FILE}

    sleep 5
    log_info "virtual disk for cinder volume is created."

    #
    # Mount to loop device
    losetup ${CINDER_LOOP_DEVICE}  ${CINDER_VG_FILE}
    
    # auto losetup after reboot
    echo "# Begin - Cinder loop device"                      >> /etc/rc.local
    echo "losetup ${CINDER_LOOP_DEVICE}  ${CINDER_VG_FILE}"  >> /etc/rc.local
    echo "# End - Cinder loop device"                        >> /etc/rc.local

    #
    # Create vg
    pvcreate ${CINDER_LOOP_DEVICE}
    vgcreate cinder-volumes ${CINDER_LOOP_DEVICE}

    log_info "volume group for cinder volume is created."
else
    # If it is a real physical disk
    if [[ $(fdisk -l ${CINDER_VG_DEVICE}) ]]; then
         log_info "cinder volume-group will be on ${CINDER_VG_DEVICE}."
         pvcreate ${CINDER_VG_DEVICE}
         vgcreate cinder-volumes ${CINDER_VG_DEVICE}
         log_info "volume group for cinder volume is created."
    else
         log_error "\"${CINDER_VG_DEVICE}\" maybe does not exist."
    fi
fi

#
# Restart service
for SVC in cinder-scheduler cinder-api cinder-volume tgt; do
    service $SVC restart
done

#
# Remove SQLite
rm -f /var/lib/cinder/cinder.sqlite
log_info "SQLite database is removed."


# ------------------------------------------
# Setup horizon
# ------------------------------------------
#
# Install horizon
install_pkg openstack-dashboard
# Remove ubuntu-theme
# apt-get -y remove --purge openstack-dashboard-ubuntu-theme

#
# Set openstack host
sed "s/OPENSTACK_HOST =.*/OPENSTACK_HOST = \"${CONTROLLER_MGMT_FQDN}\"/" \
                             -i /etc/openstack-dashboard/local_settings.py

log_info "horizon is created."

#
# Restart services
for SVC in apache2 memcached; do
    service $SVC restart
done

# ------------------------------------------
# set finish flag
# ------------------------------------------
echo "finished" > ${STATUS_STEP_4}

#
log_info "\"${SCRIPT_NAME}\" finished."
#