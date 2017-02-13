#!/bin/bash

# Internal use only
# This is a simple script to generate template and might only work for specified $CF_RELEASE_VERSION and $DIEGO_RELEASE_VERSION listed below.
# For other $CF_RELEASE_VERSION and $DIEGO_RELEASE_VERSION, you might need a change to the stubs

# Please install spiff before running this script

set -e

CF_RELEASE_VERSION="v250"
DIEGO_RELEASE_VERSION="v1.4.1"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
WORK_DIR=$(mktemp -d /tmp/upgrade-manifest.XXXXX)

echo "WORK_DIR: ${WORK_DIR}"
cd ${WORK_DIR}

# get repos
git clone https://github.com/cloudfoundry/cf-release -b ${CF_RELEASE_VERSION}
git clone https://github.com/cloudfoundry/diego-release -b ${DIEGO_RELEASE_VERSION}

# generate cf template, enable ssh-proxy, and set default backend to diego
cf_template="${WORK_DIR}/cf.yml"
spiff merge ${SCRIPT_DIR}/generic-manifest-mask.yml \
            ${SCRIPT_DIR}/cf/test-stub.yml \
            ${SCRIPT_DIR}/cf/enable-ssh.yml \
            ${WORK_DIR}/cf-release/templates/cf.yml \
            ${SCRIPT_DIR}/cf/cf-infrastructure-azure.yml \
            ${SCRIPT_DIR}/cf/cf-stub.yml \
            ${SCRIPT_DIR}/cf/disable-dea-stub.yml \
            ${SCRIPT_DIR}/cf/default-diego-backend-stub.yml \
            > ${cf_template}
echo "cf template: ${cf_template}"

# generate diego template which uses *CF* postgres for bbs database
postgres_stub=$(mktemp)
diego_template="${WORK_DIR}/diego.yml"
spiff merge ${SCRIPT_DIR}/diego/postgres/diego-sql.yml \
             ${SCRIPT_DIR}/diego/postgres/diego-sql-internal.yml \
             ${cf_template} \
             > ${postgres_stub}
${WORK_DIR}/diego-release/scripts/generate-deployment-manifest \
  -c ${cf_template} \
  -i ${SCRIPT_DIR}/diego/iaas-settings.yml \
  -p ${SCRIPT_DIR}/diego/property-overrides.yml \
  -n ${SCRIPT_DIR}/diego/instance-count-overrides.yml \
  -x \
  -s ${postgres_stub} \
  > ${diego_template}
echo "diego template: ${diego_template}"

# merge cf and diego templates
diego_template_tmp=$(mktemp)
cf_diego_template_tmp=$(mktemp)
cat ${diego_template} | sed -e 's/^resource_pools:/resource_pools:\n- <<: (( merge ))/g' | \
                      sed -e 's/^jobs:/jobs:\n- <<: (( merge ))/g' | \
                      sed -e 's/^properties:/properties:\n  <<: (( merge ))/g' | \
                      sed -e 's/^networks:/networks:\n- <<: (( merge ))/g' | \
                      sed -e 's/^releases:/releases:\n- <<: (( merge ))/g' \
                      > ${diego_template_tmp}
spiff merge ${SCRIPT_DIR}/generic-manifest-mask.yml \
            ${diego_template_tmp} \
            ${cf_template} \
            > ${cf_diego_template_tmp}
echo "cf diego template: ${cf_diego_template_tmp}"

# handle errands
python ${SCRIPT_DIR}/handle_errands.py ${cf_template} ${diego_template} ${cf_diego_template_tmp}

multiple_vm_template="${WORK_DIR}/multiple-vm-cf.yml"
cp ${cf_diego_template_tmp} ${multiple_vm_template}
echo "multiple vm template is generated at: ${multiple_vm_template}"
