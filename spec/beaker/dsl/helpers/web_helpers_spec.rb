require 'spec_helper'

class ClassMixedWithDSLHelpers
  include Beaker::DSL::Helpers
  include Beaker::DSL::Wrappers
  include Beaker::DSL::Roles
  include Beaker::DSL::Patterns

  def logger
    RSpec::Mocks::Double.new('logger').as_null_object
  end

end

describe ClassMixedWithDSLHelpers do

  def fetch_allows
    allow(subject).to receive( :logger ) { logger }
  end

  describe "#fetch_http_file" do
    let( :logger) { double("Beaker::Logger", :notify => nil , :debug => nil ) }

    before do
      fetch_allows
    end

    describe "given valid arguments" do

      it "returns its second and third arguments concatenated." do
        create_files(['destdir/name'])
        result = subject.fetch_http_file "http://beaker.tool", "name", "destdir"
        expect(result).to eq("destdir/name")
      end

    end

    describe 'given invalid arguments' do

      it 'chomps correctly when given a URL ending with a / character' do
        expect( subject ).to receive( :open ).with( 'http://beaker.tool/name', anything )
        subject.fetch_http_file( "http://beaker.tool/", "name", "destdir" )
      end

    end

  end

  describe "#fetch_http_dir" do
    let( :logger) { double("Beaker::Logger", :notify => nil , :debug => nil ) }
    let( :result) { double(:each_line => []) }

    before do
      fetch_allows
    end

    describe "given valid arguments" do

      it "returns basename of first argument concatenated to second." do
        expect(subject).to receive(:`).with(/^wget.*/).ordered { result }
        expect($?).to receive(:to_i).and_return(0)
        result = subject.fetch_http_dir "http://beaker.tool/beep", "destdir"
        expect(result).to eq("destdir/beep")
      end

    end

  end
end
