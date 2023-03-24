require 'stringify-hash'

module Beaker
  module Options
    # A hash that treats Symbol and String keys interchangeably
    # and recursively merges hashes
    class OptionsHash < StringifyHash
      # Determine if type of ObjectHash is pe, defaults to true
      #
      # @example Use this method to test if the :type setting is pe
      #     a['type'] = 'pe'
      #     a.is_pe? == true
      #
      # @return [Boolean]
      def is_pe?
        self[:type] ? self[:type].include?('pe') : true
      end

      # Determine the puppet type of the ObjectHash
      #
      # Default is FOSS
      #
      # @example Use this method to test if the :type setting is pe
      #     a['type'] = 'pe'
      #     a.get_type == :pe
      #
      # @return [Symbol] the type given in the options
      def get_type
        case self[:type]
        when /pe/
          :pe
        else
          :foss
        end
      end

      def dump_to_file(output_file)
        dirname = File.dirname(output_file)
        FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
        File.write(output_file, dump)
      end
    end
  end
end
