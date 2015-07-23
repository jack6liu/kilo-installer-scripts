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
KEY_TGZ="${LIB_CONF_DIR}/ssh-key.tgz"

#
# Step-status
STATUS_STEP_1="/etc/kilo-installer/step-1"

# ------------------------------------------
# Source base functions
# ------------------------------------------
if [[ ! -e "${PS_UTILS}" ]]; then
    echo "Error: \"${PS_UTILS}\" is not found!"
    exit 1
fi 
source ${PS_UTILS}

#
log_info "\"${SCRIPT_NAME}\" started ."
#

# ------------------------------------------
# Generate ssh key file for root user
# ------------------------------------------
#
log_info "Generating ssh key files for root ..."

if [[ -e "${KEY_TGZ}" ]]; then
    tar -zxvf ${KEY_TGZ} -C /root/
else
    log_error "\"${KEY_TGZ}\" is not found!"
fi

# ------------------------------------------
# set finish flag
# ------------------------------------------
echo "finished" > ${STATUS_STEP_1}

#
log_info "\"${SCRIPT_NAME}\" finished ."
#