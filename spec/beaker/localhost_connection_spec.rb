require 'spec_helper'
require 'net/ssh'

module Beaker
  describe LocalConnection do
    subject(:connection) { described_class.new(options) }

    let( :options )   { { :logger => double('logger').as_null_object, :ssh_env_file => '/path/to/ssh/file'} }


    before do
      allow( subject ).to receive(:sleep)
    end

    describe '#self.connect' do
      it 'loggs message' do
        expect(options[:logger]).to receive(:debug).with('Local connection, no connection to start')
        connection_constructor = described_class.connect(options)
        expect( connection_constructor ).to be_a_kind_of described_class
      end
    end

    describe '#close' do
      it 'logs message' do
        expect(options[:logger]).to receive(:debug).with('Local connection, no connection to close')
        connection.close
      end
    end

    describe '#with_env' do
      it 'sets envs temporarily' do
        connection.connect
        connection.with_env({'my_env' => 'my_env_value'}) do
          expect(ENV.to_hash).to include({'my_env' => 'my_env_value'})
        end
        expect(ENV.to_hash).not_to include({'my_env' => 'my_env_value'})
      end
    end

    describe '#execute' do
      it 'calls open3' do
        expect( Open3 ).to receive( :capture3 ).with({}, 'my_command')
        connection.connect
        expect(connection.execute('my_command')).to be_a_kind_of Result
      end

      it 'sets stdout, stderr and exitcode' do
        allow(Open3).to receive(:capture3).and_return(['stdout', 'stderr', double({exitstatus: 0})])
        connection.connect
        result = connection.execute('my_command')
        expect(result.exit_code).to eq(0)
        expect(result.stdout).to eq('stdout')
        expect(result.stderr).to eq('stderr')
      end

      it 'sets logger last_result' do
        allow(Open3).to receive(:capture3).and_return(['stdout', 'stderr', double({exitstatus: 0})])
        expect(options[:logger]).to receive(:last_result=).with(an_instance_of(Result))
        connection.connect
        connection.execute('my_command')
      end

      it 'sets exitcode to 1, when Open3 raises exeception' do
        allow(Open3).to receive(:capture3).and_raise Errno::ENOENT
        connection.connect
        result = connection.execute('my_failing_command')
        expect(result.exit_code).to eq(1)
      end
    end

    describe '#scp_to' do
      let(:source) { '/source/path' }
      let(:dest) { '/dest/path' }

      it 'calls FileUtils.cp_r' do
        connection.connect
        expect(FileUtils).to receive(:cp_r).with(source, dest)
        connection.scp_to(source, dest)
      end

      it 'returns and Result object' do
        expect(FileUtils).to receive(:cp_r).and_return(true)
        connection.connect
        result = connection.scp_to(source, dest)
        expect(result.exit_code).to eq(0)
        expect(result.stdout).to eq("  CP'ed file #{source} to #{dest}")
      end

      it 'catches exception and logs warning message' do
        allow(FileUtils).to receive(:cp_r).and_raise Errno::ENOENT
        expect(options[:logger]).to receive(:warn).with("Errno::ENOENT error in cp'ing. Forcing the connection to close, which should raise an error.")
        connection.connect
        connection.scp_to(source, dest)
      end
    end

    describe '#scp_from' do
      let(:source) { '/source/path' }
      let(:dest) { '/dest/path' }

      it 'callse scp_to with reversed params' do
        expect(connection).to receive(:scp_to).with(dest, source, {})
        connection.connect
        connection.scp_from(source, dest)
      end
    end
  end
end
