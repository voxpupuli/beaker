require 'spec_helper'

module Eos
  describe Host do
    let(:options)  { @options ? @options : {} }
    let(:platform) {
      if @platform
        { :platform => Beaker::Platform.new(@platform) }
      else
        { :platform => Beaker::Platform.new('eos-vers-arch-extra') }
      end
    }
    let(:host)    { make_host('name', options.merge(platform)) }

    describe '#get_remote_file' do
      it 'calls enable first' do
        expect(host).to receive(:execute).with(/enable/)
        host.get_remote_file('remote_url')
      end

      it 'begins second line with the copy command' do
        expect(host).to receive(:execute).with(/\ncopy/)
        host.get_remote_file('remote_url')
      end

      it 'ends second line with particular extension location' do
        expect(host).to receive(:execute).with(/extension\:\'$/)
        host.get_remote_file('remote_url')
      end
    end

    describe '#install_from_file' do
      it 'calls enable first' do
        expect(host).to receive(:execute).with(/enable/)
        host.install_from_file('local_file')
      end

      it 'begins second line with the extension command' do
        expect(host).to receive(:execute).with(/\nextension/)
        host.install_from_file('local_file')
      end
    end
  end
end
