#!/bin/bash
#

#validate_ip
function validate_ip()
{
    local ip_addr=$1
    local validate_stat=1
    if [[ $ip_addr =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip_addr=($ip_addr)
        IFS=$OIFS
        [[ ${ip_addr[0]} -lt 255 && ${ip_addr[1]} -lt 255 \
        && ${ip_addr[2]} -lt 255 && ${ip_addr[3]} -lt 255 ]]
        validate_stat=$?
    fi
    return $validate_stat
}


#validate_mask
function validate_mask()
{
    local net_mask=$1
    local validate_stat=1
    if [[ $net_mask =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        net_mask=($net_mask)
        IFS=$OIFS
        [[ ${net_mask[0]} -eq 255 && ${net_mask[1]} -le 255 \
        && ${net_mask[2]} -le 255 && ${net_mask[3]} -lt 255 ]]
        validate_stat=$?
    fi
    return $validate_stat
}


# test for validate_ip
# test -- start
echo "Enter IP Address"
read IP_ADDR
validate_ip ${IP_ADDR}

if [[ $? -ne 0 ]];then
    echo "Invalid IP Address (${IP_ADDR})"
else
    echo "${IP_ADDR} is a Perfect IP Address"
fi

echo "Enter subnet mask"
read NET_MASK
validate_mask ${NET_MASK}

if [[ $? -ne 0 ]];then
    echo "Invalid IP Address (${NET_MASK})"
else
    echo "${NET_MASK} is a Perfect IP Address"
fi

# test -- end
# apt-get install --force-yes -y