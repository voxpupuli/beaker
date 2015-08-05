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
        self[:type] ? self[:type] =~ /pe/ : true
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
        when /foss/
          :foss
        when /aio/
          :aio
        else
          :foss
        end
      end

    end
  end
end
