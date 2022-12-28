require 'spec_helper'

module Beaker
  describe PSWindows::File do
    class PSWindowsFileTest
      include PSWindows::File
      include Beaker::DSL::Wrappers

      def initialize(hash, logger)
        @hash = hash
        @logger = logger
      end

      def [](k)
        @hash[k]
      end

      def to_s
        "me"
      end
    end

    let(:opts)     { @opts || {} }
    let(:logger)   { double( 'logger' ).as_null_object }
    let(:instance) { PSWindowsFileTest.new(opts, logger) }

    describe '#cat' do
      let(:path) { '/path/to/cat' }
      let(:content) { 'file content' }

      it 'reads output for file' do
        expect(instance).to receive(:exec).and_return(double(stdout: content))
        expect(Beaker::Command).to receive(:new).with('powershell.exe', array_including("-Command type #{path}"))
        expect(instance.cat(path)).to eq(content)
      end
    end

    describe '#file_exist?' do
      let(:path) { '/path/to/test/file.txt' }

      context 'file exists' do
        it 'returns true' do
          expect(instance).to receive(:exec).and_return(double(stdout: "true\n"))
          expect(Beaker::Command).to receive(:new).with("if exist #{path} echo true")
          expect(instance.file_exist?(path)).to eq(true)
        end
      end

      context 'file does not exist' do
        it 'returns false' do
          expect(instance).to receive(:exec).and_return(double(stdout: ""))
          expect(Beaker::Command).to receive(:new).with("if exist #{path} echo true")
          expect(instance.file_exist?(path)).to eq(false)
        end
      end
    end

    describe '#tmpdir' do
      let(:tmp_path) { 'C:\\tmpdir\\' }
      let(:fake_command) { Beaker::Command.new('command1') }

      before do
        allow(instance).to receive(:execute).with(anything)
      end

      context 'with dirname sent' do
        let(:name) { 'my_dir' }

        it 'returns the path to my_dir' do
          expect(Beaker::Command).to receive(:new).
            with('powershell.exe', array_including('-Command [System.IO.Path]::GetTempPath()')).
            and_return(fake_command)
          expect(instance).to receive(:exec).with(instance_of(Beaker::Command)).and_return(double(stdout: tmp_path))

          expect(Beaker::Command).to receive(:new).
            with('powershell.exe', array_including("-Command New-Item -Path '#{tmp_path}' -Force -Name '#{name}' -ItemType 'directory'")).
            and_return(fake_command)
          expect(instance).to receive(:exec).with(instance_of(Beaker::Command)).and_return(true)

          expect(instance.tmpdir(name)).to eq(File.join(tmp_path, name))
        end
      end

      context 'without dirname sent' do
        let(:name) { '' }
        let(:random_dir) { 'dirname' }

        it 'returns the path to random name dir' do
          expect(Beaker::Command).to receive(:new).
            with('powershell.exe', array_including('-Command [System.IO.Path]::GetTempPath()')).
            and_return(fake_command)
          expect(instance).to receive(:exec).with(instance_of(Beaker::Command)).and_return(double(stdout: tmp_path))

          expect(Beaker::Command).to receive(:new).
            with('powershell.exe', array_including('-Command [System.IO.Path]::GetRandomFileName()')).
            and_return(fake_command)
          expect(instance).to receive(:exec).with(instance_of(Beaker::Command)).and_return(double(stdout: random_dir))

          expect(Beaker::Command).to receive(:new).
            with('powershell.exe', array_including("-Command New-Item -Path '#{tmp_path}' -Force -Name '#{random_dir}' -ItemType 'directory'")).
            and_return(fake_command)
          expect(instance).to receive(:exec).with(instance_of(Beaker::Command)).and_return(true)

          expect(instance.tmpdir).to eq(File.join(tmp_path, random_dir))
        end
      end
    end
  end
end
