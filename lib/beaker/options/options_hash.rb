module Beaker
  module Options
    class OptionsHash < Hash

      #override key look-up so that we can match both :key and "key" as the same
      def [] k
        super(k.to_s) || super(k.to_sym)
      end

      #override key = value ensuring that all keys are symbols
      def []=k,v
        super(k.to_sym, v)
      end

      def is_pe?
        self[:type] =~ /pe/
      end

    end
  end
end
