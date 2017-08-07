# encoding: UTF-8
require 'spec_helper'

module Beaker
  describe LoggerJunit do
    let( :xml_file ) { '/fake/file/location1' }
    let( :stylesheet ) { '/fake/file/location2' }

    describe '#is_valid_xml' do

      it 'rejects all invalid values' do
        invalid_values = [0x8, 0x10, 0xB, 0x0019, 0xD800, 0xDFFF, 0xFFFE, 0x99999, 0x110000]
        invalid_values.each do |value|
          expect( LoggerJunit.is_valid_xml(value) ).to be === false
        end
      end

      it 'accepts valid values' do
        valid_values = [0x9, 0xA, 0x0020, 0xD7FF, 0xE000, 0xFFFD, 0x100000, 0x10FFFF]
        valid_values.each do |value|
          expect( LoggerJunit.is_valid_xml(value) ).to be === true
        end
      end

    end

    describe '#escape_invalid_xml_chars' do

      it 'escapes invalid xml characters correctly' do
        testing_string = 'pants'
        testing_string << 0x8
        expect( LoggerJunit.escape_invalid_xml_chars(testing_string) ).to be === 'pants\8'
      end

      it 'leaves a string of all valid xml characters alone' do
        testing_string = 'pants man, pants!'
        expect( LoggerJunit.escape_invalid_xml_chars(testing_string) ).to be === testing_string
      end

    end

    describe '#copy_stylesheet_into_xml_dir' do

      it 'copies the stylesheet into the correct location' do
        allow( File ).to receive( :file? ) { false }
        correct_location = File.join(File.dirname(xml_file), File.basename(stylesheet))
        expect( FileUtils ).to receive( :copy ).with( stylesheet, correct_location )
        LoggerJunit.copy_stylesheet_into_xml_dir(stylesheet, xml_file)
      end

      it 'skips action if the file doesn\'t exist' do
        allow( File ).to receive( :file? ) { true }
        expect( FileUtils ).not_to receive( :copy )
        LoggerJunit.copy_stylesheet_into_xml_dir(stylesheet, xml_file)
      end

    end

    describe '#finish' do

      it 'opens the given file for writing, and writes the doc to it' do
        mock_doc = Object.new
        doc_xml = 'flibbity-floo'
        allow( mock_doc ).to receive( :write ).with(File, 2)
        expect( File ).to receive( :open ).with( xml_file, 'w' )
        LoggerJunit.finish(mock_doc, xml_file)
      end

    end

    describe '#write_xml' do

      it 'throws an error with 1-arity in the given block' do
        allow( LoggerJunit ).to receive( :get_xml_contents )
        expect{ LoggerJunit.write_xml(xml_file, stylesheet) do |hey| end }.to raise_error(ArgumentError)
      end

      it 'doesn\'t throw an error with 2-arity in the given block' do
        allow( LoggerJunit ).to receive( :get_xml_contents )
        allow( LoggerJunit ).to receive( :finish )
        expect{ LoggerJunit.write_xml(xml_file, stylesheet) do |hey1, hey2| end }.not_to raise_error
      end

      it 'throws an error with 3-arity in the given block' do
        allow( LoggerJunit ).to receive( :get_xml_contents )
        expect{ LoggerJunit.write_xml(xml_file, stylesheet) do |hey1, hey2, hey3| end }.to raise_error(ArgumentError)
      end

    end
  end
end
