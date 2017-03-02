# -*- coding: utf-8 -*-
require 'hocon'
require 'hocon/config_error'
require 'inifile'

module Beaker
  module DSL
    module Helpers
      # Convenience methods for modifying and reading TrapperKeeper configs
      module TKHelpers

        # Modify the given TrapperKeeper config file.
        #
        # @param [Host] host  A host object
        # @param [OptionsHash] options_hash  New hash which will be merged into
        #                                    the given TrapperKeeper config.
        # @param [String] config_file_path  Path to the TrapperKeeper config on
        #                                   the given host which is to be
        #                                   modified.
        # @param [Bool] replace  If set true, instead of updating the existing
        #                        TrapperKeeper configuration, replace it entirely
        #                        with the contents of the given hash.
        #
        # @note TrapperKeeper config files can be HOCON, JSON, or Ini. We don't
        # particularly care which of these the file named by `config_file_path` on
        # the SUT actually is, just that the contents can be parsed into a map.
        #
        def modify_tk_config(host, config_file_path, options_hash, replace=false)
          if options_hash.empty?
            return nil
          end

          new_hash = Beaker::Options::OptionsHash.new

          if replace
            new_hash.merge!(options_hash)
          else
            if not host.file_exist?( config_file_path )
              raise "Error: #{config_file_path} does not exist on #{host}"
            end
            file_string = host.exec( Command.new( "cat #{config_file_path}" )).stdout

            begin
              tk_conf_hash = read_tk_config_string(file_string)
            rescue RuntimeError
              raise "Error reading trapperkeeper config: #{config_file_path} at host: #{host}"
            end

            new_hash.merge!(tk_conf_hash)
            new_hash.merge!(options_hash)
          end

          file_string = JSON.pretty_generate(new_hash)
          create_remote_file host, config_file_path, file_string
        end

        # The Trapperkeeper config service will accept HOCON (aka typesafe), JSON,
        # or Ini configuration files which means we need to safely handle the the
        # exceptions that might come from parsing the given string with the wrong
        # parser and fall back to the next valid parser in turn. We finally raise
        # a RuntimeException if none of the parsers succeed.
        #
        # @!visibility private
        def read_tk_config_string( string )
            begin
              return Hocon.parse(string)
            rescue Hocon::ConfigError
              nil
            end

            begin
              return JSON.parse(string)
            rescue JSON::JSONError
              nil
            end

            begin
              return IniFile.new(content: string)
            rescue IniFile::Error
              nil
            end

            raise "Failed to read TrapperKeeper config!"
        end
      end

    end
  end
end
