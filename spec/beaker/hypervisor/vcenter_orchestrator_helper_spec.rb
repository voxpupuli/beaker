require 'spec_helper'

module Beaker
  describe VcenterOrchestratorHelper do
    let( :logger )         { double('logger').as_null_object }
    let( :vInfo )          { { :server => "vsphere.labs.net", :user => "vco@labs.com", :pass => "supersekritpassword" } }
    let( :vcenter_orchestrator_helper ) { VcenterOrchestratorHelper.new ( vInfo.merge( { :logger => logger } ) ) }
    let( :url )            { "https://vsphere.labs.net:8280/workflows/12345678910"}
    let( :params )         { {"vm_name" => "vm01"} }
    let( :params_xml )         { '<?xml version="1.0"?>
<execution-context xmlns="http://www.vmware.com/vco">
  <parameters>
    <parameter name="vm_name" type="string">
      <string>vm01</string>
    </parameter>
  </parameters>
</execution-context>
' }

    before :each do
     stub_const( "RestClient", MockRestClient )
     @parameters_obj = vcenter_orchestrator_helper.params_to_xml(params)
    end

    describe "#load_config" do 

      it 'can load a .fog file' do
        allow( File ).to receive( :exists? ).and_return( true )
        allow( YAML ).to receive( :load_file ).and_return( fog_file_contents )

        expect( VcenterOrchestratorHelper.load_config ).to be === vInfo

      end

      it 'raises an error when the .fog file is missing' do
        allow( File ).to receive( :exists? ).and_return( false )

        expect{ VcenterOrchestratorHelper.load_config }.to raise_error( ArgumentError )

      end

    end

    describe '#params_to_xml' do

      it 'returns parameters in xml' do
        expect( vcenter_orchestrator_helper.params_to_xml(params).to_xml ).to be === params_xml
      end

    end

    describe '#validate_wf' do

      it 'returns true when parameters are correct' do
        mockrequest = MockRestClient::Request.new
        mockrequest.set_response(true)
        
        expect( vcenter_orchestrator_helper.validate_wf(url, @parameters_obj) ).to be === true
      end

      it 'returns false when parameters are incorrect' do
        mockrequest = MockRestClient::Request.new
        mockrequest.set_response(false)

        expect( vcenter_orchestrator_helper.validate_wf(url, @parameters_obj) ).to be === false
      end

    end

    describe '#javascript_class_type' do

      it 'returns string when a String is passed to it' do
        expect( vcenter_orchestrator_helper.javascript_class_type("a string") ).to be === "string"
      end

      it 'returns number when a Fixnum is passed to it' do
        expect( vcenter_orchestrator_helper.javascript_class_type(1) ).to be === "number"
      end

      it 'returns boolean when true is passed to it' do
        expect( vcenter_orchestrator_helper.javascript_class_type(true) ).to be === "boolean"
      end

      it 'returns Array/number when an array of Fixnum is passed to it' do
        expect( vcenter_orchestrator_helper.javascript_class_type([1]) ).to be === "Array/number"
      end

    end

    describe '#run_workflow' do

      it 'returns the COMPLETED workflow status' do
        allow( vcenter_orchestrator_helper ).to receive( :sleep ).and_return( true )
        allow( vcenter_orchestrator_helper ).to receive( :params_to_xml ).and_return( @parameters_obj )
        allow( vcenter_orchestrator_helper ).to receive( :validate_wf ).and_return( true )
        mockrequest = MockRestClient::Request.new
        mockrequest.set_response("COMPLETED")

        expect( vcenter_orchestrator_helper.run_workflow(url, params) ).to be === "COMPLETED"
      end

      it 'Gets the workflow status until it returns completed' do    
        allow( vcenter_orchestrator_helper ).to receive( :sleep ).and_return( true )
        allow( vcenter_orchestrator_helper ).to receive( :params_to_xml ).and_return( @parameters_obj )
        allow( vcenter_orchestrator_helper ).to receive( :validate_wf ).and_return( true )

        @times_run = 0
        allow( vcenter_orchestrator_helper ).to receive( :get_wf_status ) do |url|
          if @times_run < 2
            @times_run += 1
            "RUNNING"
          else
            "COMPLETED"
          end
        end
        
        expect( vcenter_orchestrator_helper ).to receive(:get_wf_status).exactly(3).times
        vcenter_orchestrator_helper.run_workflow(url, params)
      end

    end

  end

end