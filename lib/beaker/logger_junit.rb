require 'rexml/document'
module Beaker
  # The Beaker JUnit Logger class
  # This module handles message reporting from Beaker to the JUnit format
  #
  # There is a specific pattern for using this class.
  # Here's a list of example usages:
  # - {Beaker::TestSuiteResult#write_junit_xml}
  module LoggerJunit

    # writes the xml created in the block to the xml file given
    #
    # Note: Error Recovery should take place in the caller of this
    # method in order to recover gracefully
    #
    # @param [String] xml_file Path to the xml file
    # @param [String] stylesheet Path to the stylesheet file
    # @param [Proc]   block XML message construction block
    #
    # @return nil
    def self.write_xml(xml_file, stylesheet, &block)
      doc, suites = self.get_xml_contents(xml_file, name, stylesheet)

      if block_given?
        case block.arity
        when 2
          yield doc, suites
        else
          raise ArgumentError.new "write_xml block takes 2 arguments, not #{block.arity}"
        end
      end

      self.finish(doc, xml_file)
    end

    # writes out xml content for a doc
    #
    # @param [REXML::Document] doc doc containing content to write
    # @param [String] xml_file Path to the xml file to write
    #
    # @return nil
    def self.finish(doc, xml_file)
      # junit/name.xml will be created in a directory relative to the CWD

      File.open(xml_file, 'w') { |f| doc.write(f, 2) }
    end

    # gets the xml doc & suites in order to build your xml output on top of
    #
    # @param [String] xml_file Path to the xml file
    # @param [String] name Name of the testsuite you're writing
    # @param [String] stylesheet Path to the stylesheet file
    #
    # @return [REXML::Document] doc to use for your xml content
    # @return [REXML::Element] suites to add your content to
    def self.get_xml_contents(xml_file, name, stylesheet)
      self.copy_stylesheet_into_xml_dir(stylesheet, xml_file)
      xml_file_already_exists = File.file?(xml_file)
      doc = self.get_doc_for_filename(xml_file, stylesheet, xml_file_already_exists)
      suites = self.get_testsuites_from_doc(doc, name, xml_file_already_exists)
      return doc, suites
    end

    # copies given stylesheet into the directory of the xml file given
    #
    # @param [String] stylesheet Path to the stylesheet file
    # @param [String] xml_file Path to the xml file
    #
    # @return nil
    def self.copy_stylesheet_into_xml_dir(stylesheet, xml_file)
      if not File.file?(File.join(File.dirname(xml_file), File.basename(stylesheet)))
        FileUtils.copy(stylesheet, File.join(File.dirname(xml_file), File.basename(stylesheet)))
      end
    end

    # sets up doc & gives us the suites for the testsuite named
    #
    # @param [REXML::Document] doc Doc that you're getting suites from
    # @param [String] name Testsuite node name
    # @param [Boolean] already_existed Whether or not the doc already existed
    #
    # @return [Rexml::Element] testsuites
    def self.get_testsuites_from_doc(doc, name, already_existed)
      #check to see if an output file already exists, if it does add or replace test suite data
      if already_existed
        suites = REXML::XPath.first(doc, "testsuites")
        #remove old data
        suites.elements.each("testsuite") do |e|
          if e.name =~ /#{name}/
            suites.delete_element e
          end
        end
      else
        suites = doc.add_element(REXML::Element.new('testsuites'))
      end
      return suites
    end

    # gives the document object for a particular file
    #
    # @param [String] filename Path to the file that you're opening
    # @param [String] stylesheet Path to the stylesheet for this doc
    # @param [Boolean] already_exists Whether or not the file already exists
    #
    # @return [REXML::Document] Doc that you want to write in
    def self.get_doc_for_filename(filename, stylesheet, already_exists)
      if already_exists
        doc           = REXML::Document.new File.open(filename)
      else
        #no existing file, create a new one
        doc           = REXML::Document.new
        doc << REXML::XMLDecl.new(version="1.0", encoding="UTF-8")
        instruction_content = "type='text/xsl' href='#{File.basename(stylesheet)}'"
        doc << REXML::Instruction.new(target="xml-stylesheet", content=instruction_content)
      end
      return doc
    end

    # Remove color codes and invalid XML characters from provided string
    # @param [String] string The string to format
    # @return [String] the correctly formatted cdata
    def self.format_cdata string
      self.escape_invalid_xml_chars(Logger.strip_color_codes(string))
    end

    # Escape invalid XML UTF-8 codes from provided string, see http://www.w3.org/TR/xml/#charsets for valid
    # character specification
    # @param [String] string The string to remove invalid codes from
    # @return [String] Properly escaped string
    def self.escape_invalid_xml_chars string
      escaped_string = ""
      string.chars.each do |i|
        char_as_codestring = i.unpack("U*").join
        if self.is_valid_xml(char_as_codestring.to_i)
          escaped_string << i
        else
          escaped_string << "\\#{char_as_codestring}"
        end
      end
      escaped_string
    end

    # Determine if the provided number falls in the range of accepted xml unicode values
    # See http://www.w3.org/TR/xml/#charsets for valid for valid character specifications.
    # @param [Integer] int The number to check against
    # @return [Boolean] True, if the number corresponds to a valid xml unicode character, otherwise false
    def self.is_valid_xml(int)
      return ( int == 0x9 or
        int == 0xA or
        ( int >= 0x0020 and int <= 0xD7FF ) or
        ( int >= 0xE000 and int <= 0xFFFD ) or
        ( int >= 0x100000 and int <= 0x10FFFF )
      )
    end

  end
end
