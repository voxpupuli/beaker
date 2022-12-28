require 'spec_helper'

module Beaker
  describe Platform do

    let( :logger )    { double( 'logger' ) }
    let( :platform )  { described_class.new(@name) }

    context 'initialize' do

      describe "recognizes valid platforms" do

        it "accepts correctly formatted platform values" do
          @name = 'oracle-version-arch'
          expect{ platform }.not_to raise_error
        end

        it "rejects non-supported osfamilies" do
          @name = 'amazon6-version-arch'
          expect{ platform }.to raise_error(ArgumentError)
        end

        it "rejects platforms without version/arch" do
          @name = 'ubuntu-5'
          expect{ platform }.to raise_error(ArgumentError)
        end

        it "rejects platforms that do not have osfamily at start of string" do
          @name = 'o3l-r5-u6-x86'
          expect{ platform }.to raise_error(ArgumentError)
        end

      end

      describe "if platform does not have codename" do

        it "sets codename to nil" do
          @name = "centos-6.5-x86_64"
          expect(platform.codename).to be_nil
        end

      end

      describe "platforms with version and codename" do
        it "intializes both version and codename if given version" do
          @name = "debian-7-x86_64"
          expect(platform.version).to eq('7')
          expect(platform.codename).to eq('wheezy')
        end

        it "intializes both version and codename if given codename" do
          @name = "debian-wheezy-x86_64"
          expect(platform.version).to eq('7')
          expect(platform.codename).to eq('wheezy')
        end
      end
    end

    context 'to_array' do

      it "converts Beaker::Platform object to array of its attribues" do
        @name = 'debian-7-somethingsomething'
        expect( platform.to_array ).to be === ['debian', '7', 'somethingsomething', 'wheezy']
      end

    end

    context 'with_version_codename' do

      it "can convert debian-11-xxx to debian-bullseye-xxx" do
        @name = 'debian-11-xxx'
        expect( platform.with_version_codename ).to be === 'debian-bullseye-xxx'
      end

      it "can convert debian-7-xxx to debian-wheezy-xxx" do
        @name = 'debian-7-xxx'
        expect( platform.with_version_codename ).to be === 'debian-wheezy-xxx'
      end

      it "can convert debian-6-xxx to debian-squeeze-xxx" do
        @name = 'debian-6-xxx'
        expect( platform.with_version_codename ).to be === 'debian-squeeze-xxx'
      end

      it "can convert ubuntu-2204-xxx to ubuntu-jammy-xxx" do
        @name = 'ubuntu-2204-xxx'
	expect( platform.with_version_codename ).to be === 'ubuntu-jammy-xxx'
      end

      it "can convert ubuntu-2004-xxx to ubuntu-focal-xxx" do
        @name = 'ubuntu-2004-xxx'
        expect( platform.with_version_codename ).to be === 'ubuntu-focal-xxx'
      end

      it "can convert ubuntu-1604-xxx to ubuntu-xenial-xxx" do
        @name = 'ubuntu-1604-xxx'
        expect( platform.with_version_codename ).to be === 'ubuntu-xenial-xxx'

      end

      it "can convert ubuntu-1310-xxx to ubuntu-saucy-xxx" do
        @name = 'ubuntu-1310-xxx'
        expect( platform.with_version_codename ).to be === 'ubuntu-saucy-xxx'
      end

      it "can convert ubuntu-12.10-xxx to ubuntu-quantal-xxx" do
        @name = 'ubuntu-12.10-xxx'
        expect( platform.with_version_codename ).to be === 'ubuntu-quantal-xxx'
      end

      it "can convert ubuntu-10.04-xxx to ubuntu-lucid-xxx" do
        @name = 'ubuntu-10.04-xxx'
        expect( platform.with_version_codename ).to be === 'ubuntu-lucid-xxx'
      end

      ['centos','redhat'].each do |p|
        it "leaves #{p}-7-xxx alone" do
          @name = "#{p}-7-xxx"
          expect( platform.with_version_codename ).to be === "#{p}-7-xxx"
        end
      end
    end

    context 'with_version_number' do

      it "can convert debian-wheezy-xxx to debian-7-xxx" do
        @name = 'debian-wheezy-xxx'
        expect( platform.with_version_number ).to be === 'debian-7-xxx'
      end

      it "can convert debian-squeeze-xxx to debian-6-xxx" do
        @name = 'debian-squeeze-xxx'
        expect( platform.with_version_number ).to be === 'debian-6-xxx'
      end

      it "can convert ubuntu-saucy-xxx to ubuntu-1310-xxx" do
        @name = 'ubuntu-saucy-xxx'
        expect( platform.with_version_number ).to be === 'ubuntu-1310-xxx'
      end

      it "can convert ubuntu-quantal-xxx to ubuntu-1210-xxx" do
        @name = 'ubuntu-quantal-xxx'
        expect( platform.with_version_number ).to be === 'ubuntu-1210-xxx'
      end

      ['centos','redhat'].each do |p|
        it "leaves #{p}-7-xxx alone" do
          @name = "#{p}-7-xxx"
          expect( platform.with_version_number ).to be === "#{p}-7-xxx"
        end
      end
    end

    context 'round tripping from yaml' do
      before do
        @name = 'ubuntu-14.04-x86_64'
      end

      let(:round_tripped) do
        # Ruby 2 has no unsafe_load
        if YAML.respond_to?(:unsafe_load)
          YAML.unsafe_load(YAML.dump(platform))
        else
          YAML.load(YAML.dump(platform)) # rubocop:disable Security/YAMLLoad
        end
      end

      [:variant, :arch, :version, :codename].each do |field|
        it "deserializes the '#{field}' field" do
          expect(round_tripped.send(field)).to eq platform.send(field)
        end
      end

      it 'properly sets the string contents' do
        expect(round_tripped.to_s).to eq @name
      end
    end
  end
end
