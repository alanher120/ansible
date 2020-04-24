#!/bin/bash

source /home/heat-admin/overcloudrc

# Current folder
local_path=`pwd`

OSP_PID=`echo $$`

function getStack(){
    openstack stack list | egrep -v "^#|^$|^\+" | grep "CREATE_COMPLETE" | sed s/[[:space:]]//g > ${local_path}/tmp_${OSP_PID}.log
}

function getLimit(){
    STACK_LIMIT=`cat ${local_path}/tmp_${OSP_PID}.log | wc -l`
}

# Get public IP
function getIP(){
    # Floating_IP
    NUM=$(( $COUNT + 1 ))
    STACK_ID[$COUNT]=`sed -n "${NUM}p" ${local_path}/tmp_${OSP_PID}.log | awk -F "|" '{print $2}'`
    #echo "STACK ID : "${STACK_ID[$COUNT]}
    FLOATING_IP[$COUNT]=`openstack stack show ${STACK_ID[$COUNT]} | grep  -A1 "output_key: server1_public_ip" | sed s/[[:space:]]//g | awk -F "|" '{print $3}' | grep "output_value" | awk -F ":" '{print $2}'`
    #echo "FLOATING_IP : "${FLOATING_IP[$COUNT]}

    PUBLIC_IP=`echo ${FLOATING_IP[$COUNT]} | egrep -o '[0-9]{1,2}\.[0-9]{1,3}\.[0-9]{1,3}\.[101-112]{1,3}' | head -n 1`
}

function getParameter(){
    # Catch Floating_IP ID
    EXTERNAL_IP_ID[$COUNT]=`openstack floating ip list | grep ${FLOATING_IP[$COUNT]}" " | awk -F "|" '{print $2}' | sed s/[[:space:]]//g`

    # Catch Floating IP Status
    EXTERNAL_IP_STATUS[$COUNT]=`openstack floating ip show ${EXTERNAL_IP_ID[$COUNT]} | grep "status" | awk -F "|" '{print $3}' | sed s/[[:space:]]//g`
}

getStack
getLimit

COUNT=0
while [ $COUNT -lt $STACK_LIMIT ]; do
    getIP
    if [[ "${PUBLIC_IP}" != "" ]]; then
        echo "PUBLIC IP: "${PUBLIC_IP}
        getParameter
        if [[ "${EXTERNAL_IP_STATUS[$COUNT]}" == "ACTIVE" ]]; then
                ### echo "Ext_IP:${EXTERNAL_IP_STATUS[$COUNT]}" >> ${local_path}/stack_${OSP_PID}.log
                ### echo "Ext_IP_Status:${ext_ip_status[$count]}" >> ${local_path}/stack_${OSP_PID}.log
                echo "${PUBLIC_IP[$COUNT]}" >> ${local_path}/stack_${OSP_PID}.log
        fi
    fi

    (( COUNT++ ))
done

if [[ -f ${local_path}/stack_${OSP_PID}.log ]]; then
    cp ${local_path}/stack_${OSP_PID}.log ${local_path}/stack_.log
    sudo rm ${local_path}/stack_${OSP_PID}.log
    sudo rm ${local_path}/tmp_${OSP_PID}.log
fi
