require 'spec_helper'

class PSWindowsUserTest
  include PSWindows::User
end

describe PSWindowsUserTest do
  let( :wmic_output ) do <<-EOS




Name=Administrator





Name=bob foo





Name=bob-dash





Name=bob.foo





Name=cyg_server








EOS
  end
  let( :command )  { 'cmd /c echo "" | wmic useraccount where localaccount="true" get name /format:value' }
  let( :host ) { double.as_null_object }
  let( :result ) { Beaker::Result.new( host, command ) }

  describe '#user_list' do

    it 'returns user names list correctly' do
      result.stdout = wmic_output
      expect( subject ).to receive( :execute ).with( command ).and_yield(result)
      expect( subject.user_list ).to be === ['Administrator', 'bob foo', 'bob-dash', 'bob.foo', 'cyg_server']
    end

    it 'yields correctly with the result object' do
      result.stdout = wmic_output
      expect( subject ).to receive( :execute ).and_yield(result)
      subject.user_list { |result|
        expect( result.stdout ).to be === wmic_output
      }
    end

  end

end
