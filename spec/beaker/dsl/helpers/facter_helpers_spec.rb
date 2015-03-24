require 'spec_helper'

class ClassMixedWithDSLHelpers
  include Beaker::DSL::Helpers
  include Beaker::DSL::Wrappers
  include Beaker::DSL::Roles
  include Beaker::DSL::Patterns

  def logger
    RSpec::Mocks::Double.new('logger').as_null_object
  end

end

describe ClassMixedWithDSLHelpers do
  let( :command ){ 'ls' }
  let( :host )   { double.as_null_object }
  let( :result ) { Beaker::Result.new( host, command ) }

  let( :master ) { make_host( 'master',   :roles => %w( master agent default)    ) }
  let( :agent )  { make_host( 'agent',    :roles => %w( agent )           ) }
  let( :custom ) { make_host( 'custom',   :roles => %w( custom agent )    ) }
  let( :dash )   { make_host( 'console',  :roles => %w( dashboard agent ) ) }
  let( :db )     { make_host( 'db',       :roles => %w( database agent )  ) }
  let( :hosts )  { [ master, agent, dash, db, custom ] }


  describe '#fact_on' do
    it 'retrieves a fact on a single host' do
      result.stdout = "family\n"
      expect( subject ).to receive(:facter).with('osfamily',{}).once
      expect( subject ).to receive(:on).and_return(result)

      expect( subject.fact_on('host','osfamily') ).to be === result.stdout.chomp
    end

    it 'retrieves an array of facts from multiple hosts' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      times = hosts.length
      result.stdout = "family\n"
      hosts.each do |host|
        expect( host ).to receive(:exec).and_return(result)
      end

      expect( subject.fact_on(hosts,'osfamily') ).to be === [result.stdout.chomp] * hosts.length

    end
  end

  describe '#fact' do
    it 'delegates to #fact_on with the default host' do
      allow( subject ).to receive(:hosts).and_return(hosts)
      expect( subject ).to receive(:fact_on).with(master,"osfamily",{}).once

      subject.fact('osfamily')
    end
  end

end
