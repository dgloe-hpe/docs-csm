#!/bin/bash
#
# Copyright 2021 Hewlett Packard Enterprise Development LP
#
set -e
BASEDIR=$(dirname $0)
. ${BASEDIR}/upgrade-state.sh
trap 'err_report' ERR

. ./myenv

state_name="PRE_CSM_UPGRADE_RESIZE"
state_recorded=$(is_state_recorded "${state_name}" $(hostname))
if [[ $state_recorded == "0" ]]; then
    echo -e "${GREEN}====> ${state_name} ... ${NOCOLOR}"
    
    /usr/share/doc/csm/upgrade/1.0/scripts/postgres-operator/pre-service-upgrade.sh

    record_state ${state_name} $(hostname)
    echo
else
    echo -e "${GREEN}====> ${state_name} has beed completed ${NOCOLOR}"
fi

state_name="CSM_SERVICE_UPGRADE"
state_recorded=$(is_state_recorded "${state_name}" $(hostname))
if [[ $state_recorded == "0" ]]; then
    echo -e "${GREEN}====> ${state_name} ... ${NOCOLOR}"
    
    ${CSM_RELEASE}/upgrade.sh
    
    record_state ${state_name} $(hostname)
    echo
else
    echo -e "${GREEN}====> ${state_name} has beed completed ${NOCOLOR}"
fi

state_name="POST_CSM_UPGRADE_RESIZE"
state_recorded=$(is_state_recorded "${state_name}" $(hostname))
if [[ $state_recorded == "0" ]]; then
    echo -e "${GREEN}====> ${state_name} ... ${NOCOLOR}"
    
    /usr/share/doc/csm/upgrade/1.0/scripts/postgres-operator/post-service-upgrade.sh
    
    record_state ${state_name} $(hostname)
    echo
else
    echo -e "${GREEN}====> ${state_name} has beed completed ${NOCOLOR}"
fi