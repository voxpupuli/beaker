require 'spec_helper'

module Beaker
  describe VcenterOrchestrator do

    before :each do
      MockVcenterOrchestratorHelper.set_config( fog_file_contents )
      MockVcenterOrchestratorHelper.set_wfs ( make_hosts() )
      stub_const( "VcenterOrchestratorHelper", MockVcenterOrchestratorHelper )
    end

    describe '#provision' do
      it 'runs provision workflow' do
        vco = Beaker::VcenterOrchestrator.new( make_hosts(), make_opts )

        vco.provision
      end

      it 'raises an error if a wf is missing' do
        hosts = make_hosts()
        hosts[0][:provision_workflow][:name] = "Unknown workflow"
        vco = Beaker::VcenterOrchestrator.new( hosts, make_opts )

        expect{ vco.provision }.to raise_error
      end

      it 'raises an error when the wf fails' do
        hosts = make_hosts()
        hosts[0][:provision_workflow][:parameters][:result] = "FAILED"
        vco = Beaker::VcenterOrchestrator.new( hosts, make_opts )

        expect{ vco.provision }.to raise_error
      end
    end

    describe '#cleanup' do
      it 'runs cleanup workflow' do
        vco = Beaker::VcenterOrchestrator.new( make_hosts(), make_opts )

        vco.cleanup
      end
    end
  end
end