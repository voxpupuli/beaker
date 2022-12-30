# -*- coding: utf-8 -*-
require 'hocon/parser/config_document_factory'
require 'hocon/config_value_factory'

module Beaker
  module DSL
    module Helpers
      # Convenience methods for modifying and reading Hocon configs
      #
      # @note For usage guides for these methods, check these sources:
      #   - {https://github.com/puppetlabs/beaker/tree/master/docs/how_to/use_hocon_helpers.md Beaker docs}.
      #   - Beaker acceptance tests in +acceptance/tests/base/dsl/helpers/hocon_helpers_test.rb+
      module HoconHelpers

        # Reads the given hocon file from a SUT
        #
        # @param [Host] host Host to get hocon file from.
        # @param [String] filename Name of the hocon file to get
        #
        # @raise ArgumentError if arguments are missing or incorrect
        # @return [Hocon::ConfigValueFactory] parsed hocon file
        def hocon_file_read_on(host, filename)
          if filename.nil? || filename.empty?
            raise ArgumentError, '#hocon_file_edit_on requires a filename'
          end
          file_contents = on(host, "cat #{filename}").stdout
          Hocon::Parser::ConfigDocumentFactory.parse_string(file_contents)
        end

        # Grabs the given hocon file from a SUT, allowing you to edit the file
        # just like you would a local one in the passed block.
        #
        # @note This method does not save the hocon file after editing. Our
        #   recommended workflow for that is included in our example. If you'd
        #   rather just save a file in-place on a SUT, then
        #   {#hocon_file_edit_in_place_on} is a better method to use.
        #
        # @example Editing a value & saving as a new file
        #   hocon_file_edit_on(hosts, 'hocon.conf') do |host, doc|
        #     doc2 = doc.set_value('a.b', '[1, 2, 3, 4, 5]')
        #     create_remote_file(host, 'hocon_latest.conf', doc2.render)
        #   end
        #
        # @param [Host,Array<Host>] hosts Host (or an array of hosts) to
        #   edit the hocon file on.
        # @param [String] filename Name of the file to edit.
        # @param [Proc] block Code to edit the hocon file.
        #
        # @yield [Host] Currently executing host.
        # @yield [Hocon::ConfigValueFactory] Doc to edit. Refer to
        #   {https://github.com/puppetlabs/ruby-hocon#basic-usage Hocon's basic usage doc}
        #   for info on how to use this object.
        #
        # @raise ArgumentError if arguments are missing or incorrect.
        # @return nil
        def hocon_file_edit_on(hosts, filename)
          if not block_given?
            msg = 'DSL method `hocon_file_edit_on` provides a given block'
            msg << ' a hocon file to edit. No block was provided.'
            raise ArgumentError, msg
          end
          block_on hosts, {} do | host |
            doc = hocon_file_read_on(host, filename)
            yield host, doc
          end
        end

        # Grabs the given hocon file from a SUT, allowing you to edit the file
        # and have those edits saved in-place of the file on the SUT.
        #
        # @note that a the crucial difference between this & {#hocon_file_edit_on}
        #   is that your Proc will need to return the
        #   {#hocon_file_edit_on Hocon::ConfigValueFactory doc}
        #   you want saved for the in-place save to work correctly.
        #
        # @note for info about parameters, please checkout {#hocon_file_edit_on}.
        #
        # @example setting an attribute & saving
        #   hocon_file_edit_in_place_on(hosts, hocon_filename) do |host, doc|
        #     doc.set_value('c.d', '[6, 2, 73, 4, 45]')
        #   end
        #
        def hocon_file_edit_in_place_on(hosts, filename)
          hocon_file_edit_on(hosts, filename) do |host, doc|
            content_doc = yield host, doc
            create_remote_file(host, filename, content_doc.render)
          end
        end

      end
    end
  end
end
