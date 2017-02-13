# Generate manifest template from stubs
The script `generate-templat` has functions of:
1. use cf stub to generate cf manifest.
1. use diego stub to generate diego manifest.
1. merge cf manifest and diego manifest into one manifest.

## Preparation
1. Install [spiff](https://github.com/cloudfoundry-incubator/spiff)
1. Install ruamel

    ```
    $ pip install ruamel.yaml
    ```

## Generate template
1. Change stubs
If you are using different version of cf-release/diego-release, you need to change the versions on `generate_template.sh`, example as below. For different version of cf-release/diego-release, the stub can be slight different, read [release note](https://github.com/cloudfoundry/cf-release/releases) and change the stubs accordingly.

    ```
    CF_RELEASE_VERSION="v244"
    DIEGO_RELEASE_VERSION="v0.1487.0"
    ```

1. Run script to generate tempalte

    ```
    $ ./generate_template.sh
    WORK_DIR: /tmp/upgrade-manifest.8KknC
    Cloning into 'cf-release'...
    ...
    multiple vm template is generated at: /tmp/upgrade-manifest.8KknC/multiple-vm-cf.yml
    ```

