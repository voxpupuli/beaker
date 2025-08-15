require 'spec_helper'

module Unix
  describe Host do
    let(:host) { make_host('name', { platform: 'el-9-64' }) }

    describe '#external_copy_base' do
      it 'returns /root' do
        copy_base = host.external_copy_base
        expect(copy_base).to be === '/root'
      end
    end

    describe '#determine_ssh_server' do
      it 'returns :openssh' do
        expect(host.determine_ssh_server).to be === :openssh
      end
    end
  end
end
