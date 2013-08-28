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

      def dump_hash(h, separator = '\t\t')
        h.each do |k, v|
          print "#{separator}#{k.to_s} => "
          if v.kind_of?(Hash)
            puts
            dump_hash(v, separator + separator)
          else
            puts "#{v.to_s}"
          end
        end
      end

      def dump
        puts "Options:"
        self.each do |opt, val|
          if val and val != []
            puts "\t#{opt.to_s}:"
            if val.kind_of?(Array)
              val.each do |v|
                puts "\t\t#{v.to_s}"
              end
            elsif val.kind_of?(Hash) || val.kind_of?(OptionsHash)
              dump_hash(val, "\t\t")
            else
              puts "\t\t#{val.to_s}"
            end
          end
        end
      end

    end
  end
end
