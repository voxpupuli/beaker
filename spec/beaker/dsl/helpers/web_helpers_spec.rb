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
  let( :logger  ) { double("Beaker::Logger", :notify => nil , :debug => nil ) }
  let( :url     ) { "http://beaker.tool" }
  let( :name    ) { "name" }
  let( :destdir ) { "destdir" }

  def fetch_allows
    allow( subject ).to receive( :logger )  { logger }
    allow( subject ).to receive( :options ) { options }
  end

  describe "#fetch_http_file" do
    let( :presets ) { Beaker::Options::Presets.new }
    let( :options ) { presets.presets.merge(presets.env_vars) }

    before do
      fetch_allows
    end

    describe "given valid arguments" do

      it "returns its second and third arguments concatenated." do
        concat_path = "#{destdir}/#{name}"
        create_files([concat_path])
        expect( logger ).to receive( :notify ).with( /^Already\ fetched\ / )
        result = subject.fetch_http_file url, name, destdir
        expect(result).to eq(concat_path)
      end

      it 'doesn\'t cache if :cache_files_locally set false' do
        options[:cache_files_locally] = false

        expect( logger ).to receive( :notify ).with( /^Fetching/ ).ordered
        expect( logger ).to receive( :notify ).with( /^\ \ and\ saving\ to\ / ).ordered
        expect( subject ).to receive( :open )

        subject.fetch_http_file( url, name, destdir )
      end

    end

    describe 'given invalid arguments' do

      it 'chomps correctly when given a URL ending with a / character' do
        expect( subject ).to receive( :open ).with( "#{url}/#{name}", anything )
        subject.fetch_http_file( url, name, destdir )
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
        result = subject.fetch_http_dir "#{url}/beep", destdir
        expect(result).to eq("#{destdir}/beep")
      end

    end

  end
end
