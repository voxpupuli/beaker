require 'spec_helper'

def bitvise_check_output which
  case which
  when :failure
    # Windows2003r2 failure output:
    <<DOC
[SC] EnumQueryServicesStatus:OpenService FAILED 1060:

The specified service does not exist as an installed service.
DOC
  when :success
    <<DOC
  SERVICE_NAME: BvSshServer
          TYPE               : 10  WIN32_OWN_PROCESS
          STATE              : 4  RUNNING
                                  (STOPPABLE, NOT_PAUSABLE, ACCEPTS_PRESHUTDOWN)
          WIN32_EXIT_CODE    : 0  (0x0)
          SERVICE_EXIT_CODE  : 0  (0x0)
          CHECKPOINT         : 0x0
          WAIT_HINT          : 0x0
DOC
  end
end

module Windows
  describe Host do
    let(:options)  { @options ? @options : {} }
    let(:platform) {
      if @platform
        { :platform => Beaker::Platform.new( @platform) }
      else
        { :platform => Beaker::Platform.new( 'windows-vers-arch-extra' ) }
      end
    }
    let(:host)    { make_host( 'name', options.merge(platform) ) }

    describe '#determine_ssh_server' do
      it 'does not care about return codes from the execute call' do
        expect( host ).to receive( :execute ).with( anything, :accept_all_exit_codes => true ).twice
        host.determine_ssh_server
      end

      it 'uses the default (:openssh) when the execute call fails' do
        output = bitvise_check_output( :failure )
        allow( host ).to receive( :execute ).and_return( output )
        expect( host.determine_ssh_server ).to be === :openssh
      end

      it 'reads bitvise status correctly' do
        output = bitvise_check_output( :success )
        allow( host ).to receive( :execute ).and_return( output )
        expect( host.determine_ssh_server ).to be === :bitvise
      end

      it 'reads Windows OpenSSH status correctly' do
        allow(host).to receive(:execute)
          .with('cmd.exe /c sc query BvSshServer', anything).and_return(bitvise_check_output(:failure))
        allow(host).to receive(:execute)
          .with('cmd.exe /c sc qc sshd', anything).and_return(<<~END)
        [SC] QueryServiceConfig SUCCESS

        SERVICE_NAME: sshd
                TYPE               : 10  WIN32_OWN_PROCESS 
                START_TYPE         : 2   AUTO_START
                ERROR_CONTROL      : 1   NORMAL
                BINARY_PATH_NAME   : C:\\Windows\\System32\\OpenSSH\\sshd.exe
                LOAD_ORDER_GROUP   : 
                TAG                : 0
                DISPLAY_NAME       : OpenSSH SSH Server
                DEPENDENCIES       : 
                SERVICE_START_NAME : LocalSystem
        END

        expect(host.determine_ssh_server).to eq :win32_openssh
      end

      it 'returns old value if it has already determined before' do
        ssh_server_before = host.instance_variable_get( :@ssh_server )
        test_value = :test916
        host.instance_variable_set( :@ssh_server, test_value )

        expect( host ).not_to receive( :execute )
        expect( host ).not_to receive( :logger )
        expect( host.determine_ssh_server ).to be === test_value
        host.instance_variable_set( :@ssh_server, ssh_server_before )
      end
    end

    describe '#external_copy_base' do
      it 'returns previously calculated value if set' do
        external_copy_base_before = host.instance_variable_get( :@external_copy_base )
        test_value = :testn8265
        host.instance_variable_set( :@external_copy_base, test_value )

        expect( host ).not_to receive( :execute )
        expect( host.external_copy_base ).to be === test_value
        host.instance_variable_set( :@external_copy_base, external_copy_base_before )
      end
    end
  end
end
