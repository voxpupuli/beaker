require 'spec_helper'

module Beaker
  describe Platform do
    let(:logger)    { double('logger') }
    let(:platform)  { described_class.new(@name) }

    context 'initialize' do
      describe "recognizes valid platforms" do
        it "accepts correctly formatted platform values" do
          @name = 'oracle-version-arch'
          expect { platform }.not_to raise_error
        end

        it "rejects non-supported osfamilies" do
          @name = 'amazon6-version-arch'
          expect { platform }.to raise_error(ArgumentError)
        end

        it "rejects platforms without version/arch" do
          @name = 'ubuntu-5'
          expect { platform }.to raise_error(ArgumentError)
        end

        it "rejects platforms that do not have osfamily at start of string" do
          @name = 'o3l-r5-u6-x86'
          expect { platform }.to raise_error(ArgumentError)
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
          @name = "debian-12-x86_64"
          expect(platform.version).to eq('12')
          expect(platform.codename).to eq('bookworm')
        end

        it "intializes both version and codename if given codename" do
          @name = "debian-bookworm-x86_64"
          expect(platform.version).to eq('12')
          expect(platform.codename).to eq('bookworm')
        end
      end
    end

    context 'to_array' do
      it "converts Beaker::Platform object to array of its attribues" do
        @name = 'debian-12-somethingsomething'
        expect(platform.to_array).to be === %w[debian 12 somethingsomething bookworm]
      end
    end

    context 'with_version_codename' do
      it "can convert debian-14-xxx to debian-forky-xxx" do
        @name = 'debian-14-xxx'
        expect(platform.with_version_codename).to be === 'debian-forky-xxx'
      end

      it "can convert debian-13-xxx to debian-trixie-xxx" do
        @name = 'debian-13-xxx'
        expect(platform.with_version_codename).to be === 'debian-trixie-xxx'
      end

      it "can convert debian-12-xxx to debian-bookworm-xxx" do
        @name = 'debian-12-xxx'
        expect(platform.with_version_codename).to be === 'debian-bookworm-xxx'
      end

      it "can convert debian-11-xxx to debian-bullseye-xxx" do
        @name = 'debian-11-xxx'
        expect(platform.with_version_codename).to be === 'debian-bullseye-xxx'
      end

      it "can convert ubuntu-2404-xxx to ubuntu-noble-xxx" do
        @name = 'ubuntu-2404-xxx'
        expect(platform.with_version_codename).to be === 'ubuntu-noble-xxx'
      end

      it "can convert ubuntu-2204-xxx to ubuntu-jammy-xxx" do
        @name = 'ubuntu-2204-xxx'
        expect(platform.with_version_codename).to be === 'ubuntu-jammy-xxx'
      end

      it "can convert ubuntu-2004-xxx to ubuntu-focal-xxx" do
        @name = 'ubuntu-2004-xxx'
        expect(platform.with_version_codename).to be === 'ubuntu-focal-xxx'
      end

      %w[centos redhat].each do |p|
        it "leaves #{p}-7-xxx alone" do
          @name = "#{p}-7-xxx"
          expect(platform.with_version_codename).to be === "#{p}-7-xxx"
        end
      end
    end

    context 'with_version_number' do
      it "can convert debian-bookworm-xxx to debian-12-xxx" do
        @name = 'debian-bookworm-xxx'
        expect(platform.with_version_number).to be === 'debian-12-xxx'
      end

      it "can convert debian-bullseye-xxx to debian-11-xxx" do
        @name = 'debian-bullseye-xxx'
        expect(platform.with_version_number).to be === 'debian-11-xxx'
      end

      it "can convert ubuntu-focal-xxx to ubuntu-2004-xxx" do
        @name = 'ubuntu-focal-xxx'
        expect(platform.with_version_number).to be === 'ubuntu-2004-xxx'
      end

      it "can convert ubuntu-jammy-xxx to ubuntu-2204-xxx" do
        @name = 'ubuntu-jammy-xxx'
        expect(platform.with_version_number).to be === 'ubuntu-2204-xxx'
      end

      %w[centos redhat].each do |p|
        it "leaves #{p}-7-xxx alone" do
          @name = "#{p}-7-xxx"
          expect(platform.with_version_number).to be === "#{p}-7-xxx"
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

      %i[variant arch version codename].each do |field|
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
