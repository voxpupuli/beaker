module Beaker
  module Options
    # A hash that treats Symbol and String keys interchangeably and recursively merges hashes
    class OptionsHash < Hash

      
      DIV = "\t"
      EOL = "\n"

      # Get value for given key, search for both k as String and k as Symbol, if not present return nil
      # @param [Object] k the key to find, searches for both k as String and k as Symbol
      #
      # @example Use this method to return the value for a given key
      #     a['key'] = 'value'
      #     a['key'] == a[:key] == 'value'
      #
      # @return [nil, Object] Return the Object found at given key, or nil if no Object found
      def [] k
        super(k.to_s) || super(k.to_sym)
      end

      # Set Symbol key to Object value
      # @param [Object] k The key to associated with the value, converted to Symbol key
      # @param [Object] v The value to store in the ObjectHash
      #
      # @example Use this method to set the value for a key
      #     a['key'] = 'value'
      #
      # @return [Object] Return the Object value just stored
      def []=k,v
        super(k.to_sym, v)
      end

      # Determine if type of ObjectHash is pe, defaults to true
      #
      # @example Use this method to return the value for a given key
      #     a['type'] = 'pe'
      #     a.is_pe? == true
      #
      # @return [Boolean] 
      def is_pe?
        self[:type] ? self[:type] =~ /pe/ : true
      end

      # Determine if key is stored in ObjectHash
      # @param [Object] k The key to find in ObjectHash, searches for both k as String and k as Symbol
      #
      # @example Use this method to set the value for a key
      #     a['key'] = 'value'
      #     a.has_key[:key] == true
      #
      # @return [Boolean] 
      def has_key? k
        super(k.to_s) || super(k.to_sym)
      end

      # Determine key=>value entry in OptionsHash, remove both value at String key and value at Symbol key
      # @param [Object] k The key to delete in ObjectHash, deletes both k as String and k as Symbol
      #
      # @example Use this method to set the value for a key
      #     a['key'] = 'value'
      #     a.delete[:key] == 'value'
      #
      # @return [Object, nil] The Object deleted at value, nil if no Object deleted
      def delete k
        super(k.to_s) || super(k.to_sym)
      end

      # Recursively merge and OptionsHash with an OptionsHash or Hash
      #
      # @param [OptionsHash]       base The hash to merge into
      # @param [OptionsHash, Hash] hash The hash to merge from
      #
      # @example
      #   base = { :key => { :subkey1 => 'subval', :subkey2 => 'subval' } }
      #   hash = { :key => { :subkey1 => 'newval'} }
      #      rmerge(base, hash) == { :key => { :subkey1 => 'newval', :subkey2 => 'subval' }
      # @return [OptionsHash] The combined bash and hash
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

      # Recursively merge self with an OptionsHash or Hash
      #
      # @param [OptionsHash, Hash] hash The hash to merge from
      #
      # @example
      #   base = { :key => { :subkey1 => 'subval', :subkey2 => 'subval' } }
      #   hash = { :key => { :subkey1 => 'newval'} }
      #      base.merge(hash) == { :key => { :subkey1 => 'newval', :subkey2 => 'subval' }
      # @return [OptionsHash] The combined hash 
      def merge hash
        rmerge(self, hash)
      end

      # Recursively generate a string describing the contents of an object
      #
      # @param [Object] opts The Object to be described
      # @param [String] pre  The format to pre-pend to described values
      # @param [String] post The format to post-pend to described values
      #
      # @example
      #   base = { :key => { :subkey1 => 'subval', :subkey2 => 'subval' } }
      #   base.rdump == "\t\tkey :\n\t\t\tsubkey : subval\n\t\t\tsubkey2 : subval\n"
      #      
      # @return [String] The description of the Object 
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

      # Recursively generate a string describing the contents self
      #
      # @example
      #   base = { :key => { :subkey1 => 'subval', :subkey2 => 'subval' } }
      #   base.dump == "Options:\n\t\tkey :\n\t\t\tsubkey : subval\n\t\t\tsubkey2 : subval\n"
      #      
      # @return [String] The description of self 
      def dump
        str = ''
        str +=  "Options:#{EOL}"
        str += rdump(self)
      end

    end
  end
end
