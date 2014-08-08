module Beaker
  module Options

    # A hash that treats Symbol and String keys interchangeably
    # and recursively merges hashes
    class OptionsHash < Hash

      # The dividor between elements when OptionsHash is dumped
      DIV = '    '

      # The end of line when dumping
      EOL = "\n"

      # Get value for given key, search for both k as String and k as Symbol,
      # if not present return nil
      #
      # @param [Object] k The key to find, searches for both k as String
      #                   and k as Symbol
      #
      # @example Use this method to return the value for a given key
      #     a['key'] = 'value'
      #     a['key'] == a[:key] == 'value'
      #
      # @return [nil, Object] Return the Object found at given key,
      #                       or nil if no Object found
      def [] k
        super(k.to_s) || super(k.to_sym)
      end

      # Set Symbol key to Object value
      # @param [Object] k The key to associated with the value,
      #                   converted to Symbol key
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
      # @example Use this method to test if the :type setting is pe
      #     a['type'] = 'pe'
      #     a.is_pe? == true
      #
      # @return [Boolean]
      def is_pe?
        self[:type] ? self[:type] =~ /pe/ : true
      end

      # Determine if key is stored in ObjectHash
      # @param [Object] k The key to find in ObjectHash, searches for
      #                   both k as String and k as Symbol
      #
      # @example Use this method to set the value for a key
      #     a['key'] = 'value'
      #     a.has_key[:key] == true
      #
      # @return [Boolean]
      def has_key? k
        super(k.to_s) || super(k.to_sym)
      end

      # Determine key=>value entry in OptionsHash, remove both value at
      # String key and value at Symbol key
      #
      # @param [Object] k The key to delete in ObjectHash,
      # deletes both k as String and k as Symbol
      #
      # @example Use this method to set the value for a key
      #     a['key'] = 'value'
      #     a.delete[:key] == 'value'
      #
      # @return [Object, nil] The Object deleted at value,
      # nil if no Object deleted
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
      #
      #   rmerge(base, hash)
      #   #=>  {:key =>
      #           {:subkey1 => 'newval',
      #            :subkey2 => 'subval'}}
      #
      # @return [OptionsHash] The combined bash and hash
      def rmerge base, hash
        return base unless hash.is_a?(Hash) || hash.is_a?(OptionsHash)
        hash.each do |key, v|
          if (base[key].is_a?(Hash) || base[key].is_a?(OptionsHash)) && (hash[key].is_a?(Hash) || hash[key].is_a?(OptionsHash))
            rmerge(base[key], hash[key])
          elsif hash[key].is_a?(Hash)
            base[key] = OptionsHash.new.merge(hash[key])
          else
            base[key]= hash[key]
          end
        end
        base
      end

      # Create new OptionsHash from recursively merged self with an OptionsHash or Hash
      #
      # @param [OptionsHash, Hash] hash The hash to merge from
      #
      # @example
      #   base = { :key => { :subkey1 => 'subval', :subkey2 => 'subval' } }
      #   hash = { :key => { :subkey1 => 'newval'} }
      #
      #   base.merge(hash)
      #   #=> {:key =>
      #         {:subkey1 => 'newval',
      #          :subkey2 => 'subval' }
      #
      # @return [OptionsHash] The combined hash
      def merge hash
        #make a deep copy into an empty hash object
        merged_hash = rmerge(OptionsHash.new, self)
        rmerge(merged_hash, hash)
      end

      # Recursively merge self with an OptionsHash or Hash
      #
      # @param [OptionsHash, Hash] hash The hash to merge from
      #
      # @example
      #   base = { :key => { :subkey1 => 'subval', :subkey2 => 'subval' } }
      #   hash = { :key => { :subkey1 => 'newval'} }
      #
      #   base.merge!(hash)
      #   #=> {:key =>
      #         {:subkey1 => 'newval',
      #          :subkey2 => 'subval' }
      #
      # @return [OptionsHash] The combined hash
      def merge! hash
        rmerge(self, hash)
      end

      # Helper for formatting collections
      # Computes the indentation level for elements of the collection
      # Yields indentation to block to so the caller can create
      # map of element strings
      # Places delimiters in the correct location
      # Joins everything with correct EOL
      #
      #
      # !@visibility private
      def as_coll( opening, closing, in_lvl, in_inc, &block )
        delim_indent = in_inc * in_lvl
        elem_indent  = in_inc * (in_lvl + 1)

        open_brace  = opening
        close_brace = delim_indent + closing

        fmtd_coll = block.call( elem_indent )
        str_coll = fmtd_coll.join( ',' + EOL )

        return open_brace + EOL + str_coll + EOL + close_brace
      end

      # Pretty prints a collection
      #
      # @param [Enumerable] collection The collection to be printed
      # @param [Integer]    in_lvl     The level of indentation
      # @param [String]     in_inc     The increment to indent
      #
      # @example
      #   base = {:key => { :subkey1 => 'subval', :subkey2 => ['subval'] }}
      #   self.fmt_collection( base )
      #   #=> '{
      #            "key": {
      #                "subkey": "subval",
      #                "subkey2": [
      #                    "subval"
      #                ]
      #            }
      #        }'
      #
      # @return [String] The collection as a pretty JSON object
      def fmt_collection( collection, in_lvl = 0, in_inc = DIV )
        if collection.respond_to? :each_pair
          string = fmt_assoc( collection, in_lvl, in_inc )
        else
          string = fmt_list( collection, in_lvl, in_inc )
        end

        return string
      end

      # Pretty prints an associative collection
      #
      # @param [#each_pair] coll    The collection to be printed
      # @param [Integer]    in_lvl  The level of indentation
      # @param [String]     in_inc  The increment to indent
      #
      # @example
      #   base = { :key => 'value', :key2 => 'value' }
      #   self.fmt_assoc( base )
      #   #=> '{
      #            "key": "value",
      #            "key2": "value"
      #        }'
      #
      # @return [String] The collection as a pretty JSON object
      def fmt_assoc( coll, in_lvl = 0, in_inc = DIV )
        if coll.empty?
          return '{}'
        else
          as_coll '{', '}', in_lvl, in_inc do |elem_indent|
            coll.map do |key, value|
              assoc_line = elem_indent + '"' + key.to_s + '"' + ': '
              assoc_line += fmt_value( value, in_lvl, in_inc )
            end
          end
        end
      end

      # Pretty prints a list collection
      #
      # @param [#each]    coll    The collection to be printed
      # @param [Integer]  in_lvl  The level of indentation
      # @param [String]   in_inc  The increment to indent
      #
      # @example
      #   base = [ 'first', 'second' ]
      #   self.fmt_list( base )
      #   #=> '[
      #            "first",
      #            "second"
      #        ]'
      #
      # @return [String] The collection as a pretty JSON object
      def fmt_list( coll, in_lvl = 0, in_inc = DIV )
        if coll.empty?
          return '[]'
        else
          as_coll '[', ']', in_lvl, in_inc do |indent|
            coll.map do |el|
              indent + fmt_value( el, in_lvl, in_inc )
            end
          end
        end
      end

      # Chooses between collection and primitive formatting
      #
      # !@visibility private
      def fmt_value( value, in_lvl = 0, in_inc = DIV )
        if value.kind_of? Enumerable and not value.is_a? String
          fmt_collection( value, in_lvl + 1, in_inc )
        else
          fmt_basic( value )
        end
      end

      # Pretty prints primitive JSON values
      #
      # @param [Object] value The collection to be printed
      #
      # @example
      #   self.fmt_value( 4 )
      #   #=> '4'
      #
      # @example
      #   self.fmt_value( true )
      #   #=> 'true'
      #
      # @example
      #   self.fmt_value( nil )
      #   #=> 'null'
      #
      # @example
      #   self.fmt_value( 'string' )
      #   #=> '"string"'
      #
      # @return [String] The value as a valid JSON primitive
      def fmt_basic( value )
        case value
        when Numeric, TrueClass, FalseClass then value.to_s
        when NilClass then "null"
        else "\"#{value}\""
        end
      end

      # Pretty print the options as JSON
      #
      # @example
      #   base = { :key => { :subkey1 => 'subval', :subkey2 => 'subval' } }
      #   base.dump
      #   #=>  '{
      #             "key": {
      #                 "subkey1": "subval",
      #                 "subkey2": 2
      #             }
      #         }
      #
      # @return [String] The description of self
      def dump
        fmt_collection( self, 0, DIV )
      end
    end
  end
end
