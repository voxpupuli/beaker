require 'spec_helper'

class ClassMixedWithDSLWrappers
  include Beaker::DSL::Wrappers
end

describe ClassMixedWithDSLWrappers do
  describe '#host_command' do
    it 'delegates to HostCommand.new' do
      expect( Beaker::HostCommand ).to receive( :new ).with( 'blah' )
      subject.host_command( 'blah' )
    end
  end

  describe '#powershell' do
    it 'passes "powershell.exe <args> -Command <command>" to Command' do
      command = subject.powershell("Set-Content -path 'fu.txt' -value 'fu'")
      expect(command.command ).to be === 'powershell.exe'
      expect( command.args).to be ===  ["-ExecutionPolicy Bypass", "-InputFormat None", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command Set-Content -path 'fu.txt' -value 'fu'"]
      expect( command.options ).to be === {}
    end

    it 'merges the arguments provided with the defaults' do
      command = subject.powershell("Set-Content -path 'fu.txt' -value 'fu'", {'ExecutionPolicy' => 'Unrestricted'})
      expect( command.command).to be === 'powershell.exe'
      expect( command.args ).to be === ["-ExecutionPolicy Unrestricted", "-InputFormat None", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command Set-Content -path 'fu.txt' -value 'fu'"]
      expect( command.options ).to be === {}
    end

    it 'uses EncodedCommand when EncodedCommand => true' do
      cmd = "Set-Content -path 'fu.txt' -value 'fu'"
      cmd = subject.encode_command(cmd)
      command = subject.powershell("Set-Content -path 'fu.txt' -value 'fu'", {'EncodedCommand' => true})
      expect(command.command ).to be === 'powershell.exe'
      expect( command.args).to be ===  ["-ExecutionPolicy Bypass", "-InputFormat None", "-NoLogo", "-NoProfile", "-NonInteractive", "-EncodedCommand #{cmd}"]
      expect( command.options ).to be === {}
    end

    it 'uses EncodedCommand when EncodedCommand => ""' do
      cmd = "Set-Content -path 'fu.txt' -value 'fu'"
      cmd = subject.encode_command(cmd)
      command = subject.powershell("Set-Content -path 'fu.txt' -value 'fu'", {'EncodedCommand' => ""})
      expect(command.command ).to be === 'powershell.exe'
      expect( command.args).to be ===  ["-ExecutionPolicy Bypass", "-InputFormat None", "-NoLogo", "-NoProfile", "-NonInteractive", "-EncodedCommand #{cmd}"]
      expect( command.options ).to be === {}
    end

    it 'uses EncodedCommand when EncodedCommand => nil' do
      cmd = "Set-Content -path 'fu.txt' -value 'fu'"
      cmd = subject.encode_command(cmd)
      command = subject.powershell("Set-Content -path 'fu.txt' -value 'fu'", {'EncodedCommand' => nil})
      expect(command.command ).to be === 'powershell.exe'
      expect( command.args).to be ===  ["-ExecutionPolicy Bypass", "-InputFormat None", "-NoLogo", "-NoProfile", "-NonInteractive", "-EncodedCommand #{cmd}"]
      expect( command.options ).to be === {}
    end

    it 'does not use EncodedCommand when EncodedCommand => false' do
      command = subject.powershell("Set-Content -path 'fu.txt' -value 'fu'", {'EncodedCommand' => false})
      expect(command.command ).to be === 'powershell.exe'
      expect( command.args).to be ===  ["-ExecutionPolicy Bypass", "-InputFormat None", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command Set-Content -path 'fu.txt' -value 'fu'"]
      expect( command.options ).to be === {}
    end

    it 'does not use EncodedCommand when EncodedCommand not present' do
      command = subject.powershell("Set-Content -path 'fu.txt' -value 'fu'", {})
      expect(command.command ).to be === 'powershell.exe'
      expect( command.args).to be ===  ["-ExecutionPolicy Bypass", "-InputFormat None", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command Set-Content -path 'fu.txt' -value 'fu'"]
      expect( command.options ).to be === {}
    end

    it 'has no -Command/-EncodedCommand when command is empty' do
      command = subject.powershell("", {"File" => 'myfile.ps1'})
      expect(command.command ).to be === 'powershell.exe'
      expect( command.args).to be ===  ["-ExecutionPolicy Bypass", "-InputFormat None", "-NoLogo", "-NoProfile", "-NonInteractive", "-File myfile.ps1"]
      expect( command.options ).to be === {}

    end
  end
end
