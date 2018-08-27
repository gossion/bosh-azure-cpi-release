# frozen_string_literal: true

module Bosh::AzureCloud
  class ObjectId
    ErrorMsg = Bosh::AzureCloud::ErrorMsg
    KEY_SEPERATOR = ';'
    attr_reader :plain_id, :id_hash

    def initialize(id_hash, plain_id = nil, url_encode = true)
      @id_hash = id_hash
      @plain_id = plain_id
      @url_encode = url_encode
    end

    # Params:
    # - id_str: [String] the id represented in string.
    # - defaults: [Hash] the default values will use.
    def self.parse_with_defaults(id_str, defaults)
      id_str_decoded = URI.decode_www_form_component(id_str)
      url_encode = id_str_decoded == id_str ? false : true
      array = id_str_decoded.split(KEY_SEPERATOR)
      id_hash = defaults
      if array.length == 1
        [id_hash, id_str_decoded, url_encode]
      else
        array.each do |item|
          ret = item.match('^([^:]*):(.*)$')
          raise Bosh::Clouds::CloudError, ErrorMsg::OBJ_ID_KEY_VALUE_FORMAT_ERROR if ret.nil?
          id_hash[ret[1]] = ret[2]
        end
        [id_hash, nil, url_encode]
      end
    end

    def to_s
      return @plain_id unless @plain_id.nil?
      array = []
      @id_hash.each { |key, value| array << "#{key}:#{value}" }
      id_str_raw = array.sort.join(KEY_SEPERATOR)
      @url_encode ? URI.encode_www_form_component(id_str_raw) : id_str_raw
    end
  end
end
