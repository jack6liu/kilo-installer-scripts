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

# ------------------------------------------
# Source base functions
# ------------------------------------------
if [[ ! -e "${PS_UTILS}" ]]; then
    echo "Error: \"${PS_UTILS}\" is not found!"
    exit 1
fi 
source ${PS_UTILS}

log_info "\"${SCRIPT_NAME}\" started ."

# ------------------------------------------
# Generate all passwords
# ------------------------------------------

#
# Checking cloud-passwords.conf
validate_and_backup "${PWD_CONF}"

#
# Generating new cloud-passwords.conf

log_info "Generating cloud passwords ..."
#
echo "# --------------------------------------------#"          > ${PWD_CONF}
echo "### portal user passwords                   ###"         >> ${PWD_CONF}
echo "# --------------------------------------------#"         >> ${PWD_CONF}
echo "ADMIN_PWD=admin"                                         >> ${PWD_CONF}
echo "DEMO_PWD=demo"                                           >> ${PWD_CONF}
echo "# --------------------------------------------#"         >> ${PWD_CONF}
echo "### system account passwords                ###"         >> ${PWD_CONF}
echo "# --------------------------------------------#"         >> ${PWD_CONF}
echo "DB_PWD=$(openssl rand -hex 10)"                          >> ${PWD_CONF}
echo "RABBIT_PWD=$(openssl rand -hex 10)"                      >> ${PWD_CONF}
echo "KEYSTONE_DB_PWD=$(openssl rand -hex 10)"                 >> ${PWD_CONF}
echo "ADMIN_TOKEN=$(openssl rand -hex 10)"                     >> ${PWD_CONF}
echo "GLANCE_DB_PWD=$(openssl rand -hex 10)"                   >> ${PWD_CONF}
echo "GLANCE_PWD=$(openssl rand -hex 10)"                      >> ${PWD_CONF}
echo "NOVA_DB_PWD=$(openssl rand -hex 10)"                     >> ${PWD_CONF}
echo "NOVA_PWD=$(openssl rand -hex 10)"                        >> ${PWD_CONF}
echo "CINDER_DB_PWD=$(openssl rand -hex 10)"                   >> ${PWD_CONF}
echo "CINDER_PWD=$(openssl rand -hex 10)"                      >> ${PWD_CONF}
echo "NEUTRON_DB_PWD=$(openssl rand -hex 10)"                  >> ${PWD_CONF}
echo "NEUTRON_PWD=$(openssl rand -hex 10)"                     >> ${PWD_CONF}
echo "META_SHARED_SECRET=$(openssl rand -hex 10)"              >> ${PWD_CONF}
echo "DASH_DB_PWD=$(openssl rand -hex 10)"                     >> ${PWD_CONF}
echo "# --------------------------------------------#"         >> ${PWD_CONF}
echo "### NOT used passwords                      ###"         >> ${PWD_CONF}
echo "# --------------------------------------------#"         >> ${PWD_CONF}
echo "#HEAT_DB_PWD=$(openssl rand -hex 10)"                    >> ${PWD_CONF}
echo "#HEAT_PWD=$(openssl rand -hex 10)"                       >> ${PWD_CONF}
echo "#CEILOMETER_DB_PWD=$(openssl rand -hex 10)"              >> ${PWD_CONF}
echo "#CEILOMETER_PWD=$(openssl rand -hex 10)"                 >> ${PWD_CONF}
echo "#TROVE_DB_PWD=$(openssl rand -hex 10)"                   >> ${PWD_CONF}
echo "#TROVE_PWD=$(openssl rand -hex 10)"                      >> ${PWD_CONF}

#
log_info "\"${SCRIPT_NAME}\" finished ."
#