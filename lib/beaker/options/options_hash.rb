module Beaker
  module Options
    class OptionsHash < Hash

      DIV = "\t"
      EOL = "\n"

      #override key look-up so that we can match both :key and "key" as the same
      def [] k
        super(k.to_s) || super(k.to_sym)
      end

      #override key = value ensuring that all keys are symbols
      def []=k,v
        super(k.to_sym, v)
      end

      def is_pe?
        self[:type] ? self[:type] =~ /pe/ : true
      end

      def has_key? k
        super(k.to_s) || super(k.to_sym)
      end

      def delete k
        super(k.to_s) || super(k.to_sym)
      end

      def rmerge base, hash
        return base unless hash.is_a?(Hash) || hash.is_a?(OptionsHash)
        hash.each do |key, v|
          if (base[key].is_a?(Hash) || base[key].is_a?(OptionsHash)) && (hash[key].is_a?(Hash) || has[key].is_a?(OptionsHash))
            rmerge(base[key], hash[key])
          elsif hash[key].is_a?(Hash) 
            base[key] = OptionsHash.new.merge(hash[key])
          else
            base[key]= hash[key]
          end
        end
        base
      end

      def merge hash
        rmerge(self, hash)
      end

      def rdump(opts, pre=DIV, post="")
        str = ""
        if opts.kind_of?(Hash) || opts.kind_of?(OptionsHash)
          opts.each do |k, v|
            str += "#{pre + DIV}#{k.to_s} : "
            if v.kind_of?(Hash) || v.kind_of?(OptionsHash) 
              str += EOL
              str += rdump(v, "#{pre}#{DIV}", post)
            elsif v.kind_of?(Array) and not v.empty?
              str += EOL
              str += rdump(v, "#{pre}#{DIV}#{DIV}", post)
            else
              str += "#{v.to_s}#{post}#{EOL}"
            end
          end
        elsif opts.kind_of?(Array) 
          str += "#{pre}[#{EOL}"
          opts.each do |v|
            if not v.kind_of?(Array) and not v.kind_of?(Hash) and not v.kind_of?(OptionsHash)
              str += "#{pre}#{v.to_s},#{EOL}"
            else
              str += rdump(v, pre, ",")
            end
          end
          str += "#{pre}]#{EOL}"
        end
        str
      end

      def dump
        str = ''
        str +=  "Options:#{EOL}"
        str += rdump(self)
      end

    end
  end
end
