#!/bin/bash
# vim: set sw=4 ts=4 et:

# ------------------------------------------
# Base functions for all scripts
# ------------------------------------------

function die() 
{
    echo $@
    echo "!!!SCIPRT DIED!!!"
    exit 1
}

function log_info()
{
    local DATE_TIME=$(date "+%F %T")
    echo "[${DATE_TIME}] [INFO] $@"
}

function log_warn()
{
    local DATE_TIME=$(date "+%F %T")
    echo "[${DATE_TIME}] [WARNNING] $@"
}

function log_error()
{
    local DATE_TIME=$(date "+%F %T")
    echo "[${DATE_TIME}] [ERROR] $@"
    exit 1
}

function datetime()
{
    echo "$(date +%Y%m%d-%H%M%S)"
}

function check_user()
{
    local TARGET_USER=$1
    local USER_ID=$(whoami)
    if [[ "${USER_ID}" != "${TARGET_USER}" ]]; then
        log_warn "${TARGET_USER} is required for running function."
        log_error "Current login user is ${USER_ID}."
    fi
}

function check_file()
{
    local SRC_FILE=$1
    if [[ ! -e ${SRC_FILE} ]]; then
        log_error "Error: ${SRC_FILE} is not found!"
    fi
}

function check_and_copy()
{
    local SRC_FILE=$1
    local DST_FILE=$2
    if [[ -e ${SRC_FILE} ]]; then
        cp ${SRC_FILE} ${DST_FILE}
    else
        log_error "Error: ${SRC_FILE} is not found!"
    fi

}

function check_and_backup()
{
    local SRC_FILE=$1
    local SRC_FILE_ORIG="${SRC_FILE}.orig"
    local SRC_FILE_BAK="${SRC_FILE}.bak"
    if [[ -e ${SRC_FILE} && ! -e ${SRC_FILE_ORIG} ]]; then
        cp ${SRC_FILE} ${SRC_FILE_ORIG}
    elif [[ -e ${SRC_FILE} && -e ${SRC_FILE_ORIG} ]]; then
        cp ${SRC_FILE} ${SRC_FILE_BAK}
        else
        log_error "Error: ${SRC_FILE} is not found!"
    fi
}

function validate_and_backup()
{
    local SRC_FILE=$1
    local SRC_FILE_ORIG="${SRC_FILE}.orig"
    local SRC_FILE_BAK="${SRC_FILE}.bak"
    if [[ -e ${SRC_FILE} && ! -e ${SRC_FILE_ORIG} ]]; then
        cp ${SRC_FILE} ${SRC_FILE_ORIG}
    elif [[ -e ${SRC_FILE} && -e ${SRC_FILE_ORIG} ]]; then
        cp ${SRC_FILE} ${SRC_FILE_BAK}
    else
        log_warn "WARNNING: ${SRC_FILE} is not found!"
    fi
}

function get_id()
{
    echo `$@ | awk '/ id / { print $4 }'`
}

function install_pkg()
{
    apt-get --force-yes -y install "$@"
}

function create_service_db()
{
    local DB_PWD=$1
    local OS_SERVICE=$2
    local OS_SERVICE_PWD=$3
    #mysql -u root -p${DB_PWD} -e "DROP DATABASE IF EXISTS ${OS_SERVICE};"
    #mysql -u root -p${DB_PWD} -e "CREATE DATABASE IF NOT EXISTS ${OS_SERVICE};"
    mysql -u root -p${DB_PWD} -e "CREATE DATABASE ${OS_SERVICE};"
    mysql -u root -p${DB_PWD} -e "GRANT ALL PRIVILEGES ON ${OS_SERVICE}.* \
                                  TO '${OS_SERVICE}'@'localhost'          \
                                  IDENTIFIED BY '${OS_SERVICE_PWD}';"
    mysql -u root -p${DB_PWD} -e "GRANT ALL PRIVILEGES ON ${OS_SERVICE}.* \
                                  TO '${OS_SERVICE}'@'%'                  \
                                  IDENTIFIED BY '${OS_SERVICE_PWD}';"
    mysql -u root -p${DB_PWD} -e "FLUSH PRIVILEGES;"
}

function fix_service_permission()
{
    local OS_SERVICE=$1
    chown -R ${OS_SERVICE}:${OS_SERVICE} /etc/${OS_SERVICE}
    chown -R ${OS_SERVICE}:${OS_SERVICE} /var/lib/${OS_SERVICE}
    chown -R ${OS_SERVICE}:${OS_SERVICE} /var/log/${OS_SERVICE}
}
