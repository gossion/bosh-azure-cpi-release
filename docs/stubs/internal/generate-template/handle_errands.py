from ruamel import yaml
import sys

# update cf_diego_template
# 1. inject cf_template.properties.etcd of azure-cf.yml to cf_diego_template.jobs.etcd_zX.properties
# 2. set cf_diego_template.properties.etcd to {}

cf_template       = sys.argv[1]
diego_template    = sys.argv[2]
cf_diego_template = sys.argv[3]

with open(cf_template, 'r') as stream:
    cf = yaml.load(stream)
with open(diego_template, 'r') as stream:
    diego = yaml.load(stream)
with open(cf_diego_template, 'r') as stream:
    cf_diego = yaml.load(stream)

cf_etcd_properties = cf['properties']['etcd']
diego_etcd_properties = diego['properties']['etcd']

for job in cf_diego['jobs']:
    if job['name'].startswith('etcd_z'):
        job['properties']['etcd'] = cf_etcd_properties
cf_diego['properties']['etcd'] = {}

cf_diego['properties']['loggregator'].update(cf['properties']['loggregator'])

with open(cf_diego_template, 'w') as yaml_file:
    yaml.dump(cf_diego, yaml_file, Dumper=yaml.SafeDumper, default_flow_style=False)
