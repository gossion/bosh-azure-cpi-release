module Bosh::AzureCloud
  class InstanceTypeMapper
    include Helpers

    # https://docs.microsoft.com/en-us/azure/virtual-machines/linux/sizes
    # The below array defines different series. The former series is recommended than the latter.
    # The following sizes are not recommended:
    #   The sizes with premium storage;
    #   The storage-optimized sizes (Azure CPI doesn't use temporary storage);
    #   The sizes with GPU;
    #   The Basic tier sizes (they don't support load balancing);
    #   The B-series (Preview) sizes.
    RECOMMENDED_VM_SIZES = [
      ['Standard_F1', 'Standard_F2', 'Standard_F4', 'Standard_F8', 'Standard_F16'],
      [
        'Standard_D1_v2', 'Standard_D2_v2', 'Standard_D3_v2', 'Standard_D4_v2', 'Standard_D5_v2',
        'Standard_D11_v2', 'Standard_D12_v2', 'Standard_D13_v2', 'Standard_D14_v2', 'Standard_D15_v2'
      ],
      [
        'Standard_D1', 'Standard_D2', 'Standard_D3', 'Standard_D4',
        'Standard_D11', 'Standard_D12', 'Standard_D13', 'Standard_D14'
      ],
      ['Standard_D2_v3', 'Standard_D4_v3', 'Standard_D8_v3', 'Standard_D16_v3', 'Standard_D32_v3', 'Standard_D64_v3'],
      [
        'Standard_A1', 'Standard_A2', 'Standard_A3', 'Standard_A4', 'Standard_A5', 'Standard_A6', 'Standard_A7',
        'Standard_A1_v2', 'Standard_A2_v2', 'Standard_A3_v2', 'Standard_A4_v2', 'Standard_A2m_v2', 'Standard_A4m_v2', 'Standard_A8m_v2'
      ],
      # High Memory
      [
       'Standard_E2_v3', 'Standard_E4_v3', 'Standard_E8_v3', 'Standard_E16_v3', 'Standard_E32_v3', 'Standard_E64_v3',
       'Standard_G1', 'Standard_G2', 'Standard_G3', 'Standard_G4', 'Standard_G5'
      ],
      # High Performance
      [
        'Standard_H8', 'Standard_H16', 'Standard_H8m', 'Standard_H16m', 'Standard_H16r', 'Standard_H16mr',
        'Standard_A8', 'Standard_A9', 'Standard_A10', 'Standard_A11'
      ]
    ]

    def map(vm_resources, available_vm_sizes)
      @logger = Bosh::AzureCloud::RetryableLogger.new(Bosh::Clouds::Config.logger)

      possible_vm_sizes = find_possible_vm_sizes(vm_resources, available_vm_sizes)
      if possible_vm_sizes.empty?
        raise ["Unable to meet requested vm_resources: #{vm_resources['cpu']} CPU, #{vm_resources['ram']} MB RAM.\n",
          "Available VM sizes:\n",
          available_vm_sizes.map { |vm_size| "#{vm_size[:name]}: #{vm_size[:number_of_cores]} CPU, #{vm_size[:memory_in_mb]} MB RAM\n" }
        ].join
      end
      @logger.debug("The possible VM sizes are `#{possible_vm_sizes}'")

      closest_matched_vm_size = find_closest_matched_vm_size(possible_vm_sizes)
      @logger.debug("The closest matched VM size is `#{closest_matched_vm_size}'")

      closest_matched_vm_size[:name]
    end

    private

    def find_possible_vm_sizes(vm_resources, available_vm_sizes)
      available_vm_sizes.select do |vm_size|
        vm_size[:number_of_cores] >= vm_resources['cpu'] &&
        vm_size[:memory_in_mb] >= vm_resources['ram']
      end
    end

    def find_closest_matched_vm_size(possible_vm_sizes)
      RECOMMENDED_VM_SIZES.each do |series|
        recommended_vm_sizes = possible_vm_sizes.select do |vm_size|
          series.include?(vm_size[:name])
        end
        unless recommended_vm_sizes.empty?
          return recommended_vm_sizes.min_by do |vm_size|
            [vm_size[:number_of_cores], vm_size[:memory_in_mb]]
          end
        end
      end
      cloud_error("Unable to find the closest matched VM sizes")
    end
  end
end
