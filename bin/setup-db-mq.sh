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

MYSQL_CNF="${LIB_CONF_DIR}/my.cnf"
MYSQL_OS_CNF="/etc/mysql/conf.d/mysqld_openstack.cnf"

#
# Step-status
STATUS_STEP_3="/etc/kilo-installer/step-3"

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
# Source cloud-passwords.conf
# ------------------------------------------
if [[ ! -e "${PWD_CONF}" ]]; then
    log_error "\"${PWD_CONF}\" is not found!"
fi 
source ${PWD_CONF}
log_info "\"${PWD_CONF}\" is imported."

# ------------------------------------------
# Setup mysql
# ------------------------------------------
# Install mariadb-server
export DEBIAN_FRONTEND=noninteractive
debconf-set-selections <<< 'mariadb-server-10.0 mysql-server/root_password password PASS'
debconf-set-selections <<< 'mariadb-server-10.0 mysql-server/root_password_again password PASS'

install_pkg mariadb-server
install_pkg python-mysqldb
mysql -uroot -pPASS -e "SET PASSWORD = PASSWORD('');"

# Stop mysql
service mysql stop

#
# Replace my.cnf
# validate_and_backup "/etc/mysql/my.cnf"
# cp -f ${MYSQL_CNF} /etc/mysql/my.cnf
echo "[mysqld]"                                    > ${MYSQL_OS_CNF}
echo "bind-address = 0.0.0.0"                     >> ${MYSQL_OS_CNF}
echo "default-storage-engine = innodb"            >> ${MYSQL_OS_CNF}
echo "innodb_file_per_table"                      >> ${MYSQL_OS_CNF}
echo "collation-server = utf8_general_ci"         >> ${MYSQL_OS_CNF}
echo "init-connect = 'SET NAMES utf8'"            >> ${MYSQL_OS_CNF}
echo "character-set-server = utf8"                >> ${MYSQL_OS_CNF}

log_info "mysql is configured."

# Start mysql
service mysql start

#
# Set mysql root password
#
# Get MySQL root access.
if ! $(mysqladmin -u root password ${DB_PWD}); then
    if ! echo "SELECT 1;" | mysql -u root -p${DB_PWD} > /dev/null; then
        log_warn "Failed to set password for 'root' of MySQL."
        log_error "    -- Password for 'root' is already set."
    else
        log_info "Password is set for 'root' of MySQL."
        log_info "     -- Connection to MySQL is verified."
    fi
fi

#
# Sanity check MySQL credentials.
if ! echo "SELECT 1;" | mysql -u root -p${DB_PWD} > /dev/null; then
    log_warn "Connection to MySQL server is failed." 
    log_error "    -- Please check your root credentials for MySQL." 
else
    log_info "Connection to MySQL is verified."
fi

#    
# Grant remote access of mysql root account
service mysql start

#
mysql -u root -p${DB_PWD} -e "GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY '${DB_PWD}';"
mysql -u root -p${DB_PWD} -e "FLUSH PRIVILEGES;"
log_info "Remote access for root of MySQL is granted."

# ------------------------------------------
# Setup databases for openstack services
# ------------------------------------------

# ------------------------------------------
# Setup rabbitmq-server
# ------------------------------------------
# install rabbitmq-server
install_pkg rabbitmq-server

# restart rabbitmq-server
service rabbitmq-server restart
sleep 2

# set password
#rabbitmqctl change_password guest ${RABBIT_PWD}
rabbitmqctl add_user openstack ${RABBIT_PWD}
log_info "new rabbit userid 'openstack' is set."

rabbitmqctl set_permissions openstack ".*" ".*" ".*"
log_info "permission for 'openstack' is set."
# restart rabbitmq-server again
sleep 2
service rabbitmq-server restart

# ------------------------------------------
# set finish flag
# ------------------------------------------
echo "finished" > ${STATUS_STEP_3}
sleep 2
#
log_info "\"${SCRIPT_NAME}\" finished."
#