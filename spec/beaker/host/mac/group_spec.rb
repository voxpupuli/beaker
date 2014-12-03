require 'spec_helper'

class MacGroupTest
  include Mac::Group
end

describe MacGroupTest do
  let( :puppet1 ) do <<-EOS
name: puppet1
password: *
gid: 55

EOS
  end
  let( :puppet2 ) do <<-EOS
name: puppet2
password: *
gid: 56

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

  describe '#group_list' do

    it 'returns group names list correctly' do
      result.stdout = dscacheutil_list
      expect( subject ).to receive( :execute ).and_yield(result)
      expect( subject.group_list ).to be === ['puppet1', 'puppet2']
    end

    it 'yields correctly with the result object' do
      result.stdout = dscacheutil_list
      expect( subject ).to receive( :execute ).and_yield(result)
      subject.group_list { |result|
        expect( result.stdout ).to be === dscacheutil_list
      }
    end

  end

  describe '#group_get' do

    it 'fails if a name line isn\'t included' do
      result.stdout = ''
      group_name = 'any_name'
      expect( subject ).to receive( :execute ).and_yield(result)
      expect { subject.group_get(group_name) }.to raise_error(MiniTest::Assertion, "failed to get group #{group_name}")
    end

    it 'parses mac dscacheutil output into /etc/group format correctly' do
      result.stdout = puppet1
      expect( subject ).to receive( :execute ).and_yield(result)
      subject.group_get('puppet1') do |answer|
        expect(answer).to be === 'puppet1:*:55'
      end
    end

  end

  describe '#group_gid' do

    it 'parses mac dscacheutil output into the gid correctly' do
      result.stdout = puppet1
      expect( subject ).to receive( :execute ).and_yield(result)
      expect( subject.group_gid(puppet1) ).to be === '55'
    end

    it 'returns -1 if gid not found' do
      result.stdout = ''
      expect( subject ).to receive( :execute ).and_yield(result)
      expect( subject.group_gid(puppet1) ).to be === -1
    end

  end

  describe '#group_present' do

    it 'returns group existence without running create command if it already exists' do
      result.stdout = puppet1
      expect( subject ).to receive( :execute ).once.and_yield(result)
      subject.group_present( 'puppet1' )
    end

    it 'runs correct create command if group does not exist' do
      result.stdout = ''
      gid = 512
      name = "madeup_group"

      expect( subject ).to receive( :gid_next ).and_return(gid)
      expect( subject ).to receive( :execute ).once.ordered.and_yield(result)
      expect( subject ).to receive( :execute ).with("dscl . create /Groups/#{name} && dscl . create /Groups/#{name} PrimaryGroupID #{gid}").once.ordered
      subject.group_present( name )
    end

  end

  describe '#group_absent' do

    it 'calls execute to run logic' do
      name = "main_one"
      expect( subject ).to receive( :execute ).once.with("if dscl . -list /Groups/#{name}; then dscl . -delete /Groups/#{name}; fi", {})
      subject.group_absent( name )
    end

  end

  describe '#gid_next' do

    it 'returns the next ID given' do
      n = 10
      expect( subject ).to receive( :execute ).and_return("#{n}")
      expect( subject.gid_next ).to be === n + 1
    end

  end
end
