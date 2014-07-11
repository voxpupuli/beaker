require 'spec_helper'

module Beaker
  describe Platform do

    let( :logger )    { double( 'logger' ) }
    let( :platform )  { Platform.new(@name) }

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

      it "can convert debian-7-xxx to debian-wheezy-xxx" do
        @name = 'debian-7-xxx'
        expect( platform.with_version_codename ).to be === 'debian-wheezy-xxx'
      end

      it "can convert debian-6-xxx to debian-squeeze-xxx" do
        @name = 'debian-6-xxx'
        expect( platform.with_version_codename ).to be === 'debian-squeeze-xxx'
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

      it "leaves centos-7-xxx alone" do
        @name = 'centos-7-xxx'
        expect( platform.with_version_codename ).to be === 'centos-7-xxx'
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

      it "leaves centos-7-xxx alone" do
        @name = 'centos-7-xxx'
        expect( platform.with_version_number ).to be === 'centos-7-xxx'
      end

    end

  end

end
