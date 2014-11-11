require 'spec_helper'

class MacUserTest
  include Mac::User
end

describe MacUserTest do
  let( :puppet1 ) do <<-EOS
name: puppet1
password: *
uid: 67
gid: 234
dir: /Users/puppet1
shell: /bin/bash
gecos: Unprivileged User

EOS
  end
  let( :puppet2 ) do <<-EOS
name: puppet2
password: *
uid: 68
gid: 235
dir: /Users/puppet2
shell: /bin/sh
gecos: puppet

EOS
  end
  let( :dscacheutil_list ) do <<-EOS
#{puppet1}
#{puppet2}
EOS
  end
  let( :command )  { 'ls' }
  let( :host ) { double.as_null_object }
  let( :result ) { Beaker::Result.new( host, command ) }

  describe '#user_list' do

    it 'returns user names list correctly' do
      result.stdout = dscacheutil_list
      expect( subject ).to receive( :execute ).and_yield(result)
      expect( subject.user_list ).to be === ['puppet1', 'puppet2']
    end

    it 'yields correctly with the result object' do
      result.stdout = dscacheutil_list
      expect( subject ).to receive( :execute ).and_yield(result)
      subject.user_list { |result|
        expect( result.stdout ).to be === dscacheutil_list
      }
    end

  end

  describe '#user_get' do

    it 'fails if a name line isn\'t included' do
      result.stdout = ''
      user_name = 'any_name'
      expect( subject ).to receive( :execute ).and_yield(result)
      expect { subject.user_get(user_name) }.to raise_error(MiniTest::Assertion, "failed to get user #{user_name}")
    end

    it 'parses mac dscacheutil output into /etc/passwd format correctly' do
      result.stdout = puppet1
      expect( subject ).to receive( :execute ).and_yield(result)
      expect( subject.user_get('puppet1') ).to be === "puppet1:*:67:234:puppet1:/Users/puppet1:/bin/bash"
    end

    it 'yields correctly with the result object' do
      result.stdout = puppet1
      expect( subject ).to receive( :execute ).and_yield(result)
      subject.user_get('puppet1') do |result|
        expect( result.stdout ).to be === puppet1
      end
    end

  end

  describe '#user_present' do

    it 'returns user existence without running create command if it already exists' do
      result.stdout = puppet1
      expect( subject ).to receive( :execute ).once.and_yield(result)
      subject.user_present( 'puppet1' )
    end

    it 'runs correct create command if group does not exist' do
      result.stdout = ''
      uid = 512
      gid = 1007
      name = "madeup_user"

      expect( subject ).to receive( :uid_next ).and_return(uid)
      expect( subject ).to receive( :gid_next ).and_return(gid)
      expect( subject ).to receive( :execute ).once.ordered.and_yield(result)
      expect( subject ).to receive( :execute ).once.ordered
      subject.user_present( name )
    end

  end

  describe '#user_absent' do

    it 'calls execute to run logic' do
      name = "main_one"
      expect( subject ).to receive( :execute ).once.with("if dscl . -list /Users/#{name}; then dscl . -delete /Users/#{name}; fi", {})
      subject.user_absent( name )
    end

  end

  describe '#uid_next' do

    it 'returns the next ID given' do
      n = 117
      expect( subject ).to receive( :execute ).and_return("#{n}")
      expect( subject.uid_next ).to be === n + 1
    end

  end

  describe '#gid_next' do

    it 'returns the next ID given' do
      n = 843
      expect( subject ).to receive( :execute ).and_return("#{n}")
      expect( subject.gid_next ).to be === n + 1
    end

  end
end
