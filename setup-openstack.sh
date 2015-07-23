#!/bin/bash
# vim: set sw=4 ts=4 et:

# TODO: generate role file
#
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
BIN_DIR="${SCRIPT_DIR}/bin"
LIB_DIR="${SCRIPT_DIR}/lib"
ETC_DIR="${SCRIPT_DIR}/etc"
IMG_DIR="${SCRIPT_DIR}/images"
LIB_CONF_DIR="${LIB_DIR}/conf"

LOG_DIR="${SCRIPT_DIR}/log"

#
# Config files
PS_UTILS="${LIB_DIR}/ps_utils.sh"
SYS_CONF="${ETC_DIR}/system.conf"
PWD_CONF="${ETC_DIR}/cloud-passwords.conf"

ROLE_CONF="/etc/kilo-installer/node-role.conf"
# NODE_ROLE is imported at below

# add for allinone test -- start
mkdir -p /etc/kilo-installer
echo 'allinone' | tee ${ROLE_CONF}
cp -f ${ETC_DIR}/system.conf.allinone.sample ${ETC_DIR}/system.conf

# add for allinone test -- end

#
# Step-status
STATUS_STEP_1="/etc/kilo-installer/step-1"
STATUS_STEP_2="/etc/kilo-installer/step-2"
STATUS_STEP_3="/etc/kilo-installer/step-3"
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
# Check configuration files
# ------------------------------------------
if [[ ! -e ${PWD_CONF} ]]; then
    log_warn "\"${PWD_CONF}\" is not found!"
    log_warn "Please generate cloud-passwords.conf via \"bash ${SCRIPT_DIR}/generate-passwords.sh\""
    log_warn "Or manual create cloud-passwords.conf under \"${ETC_DIR}\""
fi

if [[ ! -e ${SYS_CONF} ]]; then
    log_warn "\"${SYS_CONF}\" is not found!"
    log_error "Please manual create system.conf under \"${ETC_DIR}\""
fi

#
# make sure log folder is there
mkdir -p ${LOG_DIR}

# ------------------------------------------
# Setup sshkey for root 
# ------------------------------------------
mkdir -p ${LOG_DIR}

if [[ ! -e "${BIN_DIR}/setup-root-sshkey.sh" ]]; then
    log_error "\"${BIN_DIR}/setup-root-sshkey.sh\" is not found!"
fi

echo "=====================STEP 1 - STARTED============================="
if [[ -e "${STATUS_STEP_1}" ]]; then
    log_info "root sshkey was configured."
else
    bash ${BIN_DIR}/setup-root-sshkey.sh |& tee ${LOG_DIR}/setup-root-sshkey.log
fi

echo "=====================STEP 1 - END================================="
# ------------------------------------------
# Setup operating system
# ------------------------------------------

if [[ ! -e "${BIN_DIR}/setup-system.sh" ]]; then
    log_error "\"${BIN_DIR}/setup-system.sh\" is not found!"
fi

echo "=====================STEP 2 - STARTED============================="
if [[ -e "${STATUS_STEP_2}" ]]; then
    log_info "system was configured."
else
    bash ${BIN_DIR}/setup-system.sh |& tee ${LOG_DIR}/setup-system.log
fi

echo "=====================STEP 2 - END================================="

if [[ "${NODE_ROLE}" = "allinone" ]]; then
    # ------------------------------------------
    # setup database and amqp on controller
    # ------------------------------------------
    if [[ ! -e "${BIN_DIR}/setup-db-mq.sh" ]]; then
        log_error "\"${BIN_DIR}/setup-db-mq.sh\" is not found!"
    fi
    echo "=====================STEP 3 - STARTED============================="
    if [[ -e "${STATUS_STEP_3}" ]]; then
        log_info "database and amqp was configured."
    else
        bash ${BIN_DIR}/setup-db-mq.sh |& tee ${LOG_DIR}/setup-db-mq.log
        sleep 3
        log_info "sleep for 3 secs"
    fi
    leep 3
    log_info "sleep for 3 secs"
    echo "=====================STEP 3 - END================================="
    # ------------------------------------------
    # setup controller and compute
    # ------------------------------------------
    if [[ ! -e "${BIN_DIR}/setup-controller.sh" ]]; then
        log_error "\"${BIN_DIR}/setup-controller.sh\" is not found!"
    fi
    if [[ ! -e "${BIN_DIR}/setup-compute.sh" ]]; then
        log_error "\"${BIN_DIR}/setup-compute.sh\" is not found!"
    fi

    echo "=====================STEP 4 - STARTED============================="
    if [[ -e "${STATUS_STEP_4}" ]]; then
        log_info "Openstack allinone node was configured."
    else
        bash ${BIN_DIR}/setup-controller.sh |& tee ${LOG_DIR}/controller.log
        bash ${BIN_DIR}/setup-compute.sh |& tee ${LOG_DIR}/compute.log
    fi
    echo "=====================STEP 4 - END================================="
elif [[ "${NODE_ROLE}" = "controller" ]]; then
    # ------------------------------------------
    # setup database and amqp on controller
    # ------------------------------------------
    if [[ ! -e "${BIN_DIR}/setup-db-mq.sh" ]]; then
        log_error "\"${BIN_DIR}/setup-db-mq.sh\" is not found!"
    fi
    echo "=====================STEP 3 - STARTED============================="
    if [[ -e "${STATUS_STEP_3}" ]]; then
        log_info "database and amqp was configured."
    else
        bash ${BIN_DIR}/setup-db-mq.sh |& tee ${LOG_DIR}/setup-db-mq.log
    fi
    echo "=====================STEP 3 - END================================="
    # ------------------------------------------
    # setup controller
    # ------------------------------------------
    if [[ ! -e "${BIN_DIR}/setup-controller.sh" ]]; then
        log_error "\"${BIN_DIR}/setup-controller.sh\" is not found!"
    fi

    echo "=====================STEP 4 - STARTED============================="
    if [[ -e "${STATUS_STEP_4}" ]]; then
        log_info "Openstack controller node was configured."
    else
        bash ${BIN_DIR}/setup-controller.sh |& tee ${LOG_DIR}/controller.log
    fi
    echo "=====================STEP 4 - END================================="
elif [[ "${NODE_ROLE}" = "compute" ]]; then
    # ------------------------------------------
    # setup compute
    # ------------------------------------------
    if [[ ! -e "${BIN_DIR}/setup-compute.sh" ]]; then
        log_error "\"${BIN_DIR}/setup-compute.sh\" is not found!"
    fi

    echo "=====================STEP 4 - STARTED============================="
    if [[ -e "${STATUS_STEP_4}" ]]; then
        log_info "Openstack compute node was configured."
    else
        bash ${BIN_DIR}/setup-compute.sh |& tee ${LOG_DIR}/compute.log
    fi
    echo "=====================STEP 4 - END================================="
fi

#
log_info "\"${SCRIPT_NAME}\" finished."
#