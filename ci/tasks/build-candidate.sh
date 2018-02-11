#!/usr/bin/env bash

set -e

source bosh-cpi-src/ci/utils.sh
source /etc/profile.d/chruby.sh
chruby ${RUBY_VERSION}

semver=`cat version-semver/number`

pushd bosh-cpi-src > /dev/null
  # Replace the version with semantic one in source code
  # The version will be added in the release tarball, but not updated to upstream
  version_file='src/bosh_azure_cpi/lib/cloud/azure/version.rb'
  cat > $version_file << EOF
module Bosh
  module AzureCloud
    VERSION = '$semver'.freeze
  end
end
EOF

  echo "running unit tests"
  pushd src/bosh_azure_cpi > /dev/null
    bundle install
    # AZURE_STORAGE_ACCOUNT and AZURE_STORAGE_ACCESS_KEY are specified fake values as a workaround
    # to make sure Azure::Storage::Client is mocked successfully in unit tests.
    # After https://github.com/Azure/azure-storage-ruby/issues/87 is resolved, they can be removed.
    # echo "bar" | base64 => YmFyCg==
    AZURE_STORAGE_ACCOUNT="foo" AZURE_STORAGE_ACCESS_KEY="YmFyCg==" bundle exec rspec spec/unit/* --format documentation
  popd > /dev/null

  cpi_release_name="bosh-azure-cpi"

  echo "building CPI release..."
  bosh create-release --name $cpi_release_name --version $semver --tarball ../candidate/$cpi_release_name-$semver.tgz --force
  # Revert the change of versioning file
  git checkout $version_file
popd > /dev/null
