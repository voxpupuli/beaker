require 'spec_helper'

module Beaker
  describe VsphereHelper do
    let( :logger )         { double('logger').as_null_object }
    let( :vInfo )          { { :server => "vsphere.labs.net", :user => "vsphere@labs.com", :pass => "supersekritpassword" } }
    let( :vsphere_helper ) { VsphereHelper.new ( vInfo.merge( { :logger => logger } ) ) }
    let( :snaplist )       { { 'snap1' => { 'snap1sub1' => nil ,
                                            'snap1sub2' => nil },
                               'snap2' => nil,
                               'snap3' => { 'snap3sub1' => nil ,
                                            'snap3sub2' => nil ,
                                            'snap3sub3' => nil } } }
    let( :vms )            {  [ MockRbVmomiVM.new( 'mockvm1', snaplist ),
                                MockRbVmomiVM.new( 'mockvm2', snaplist ),
                                MockRbVmomiVM.new( 'mockvm3', snaplist ) ] }

    before :each do
     stub_const( "RbVmomi", MockRbVmomi )
    end

    describe "#load_config" do

      it 'can load a .fog file' do
        allow( File ).to receive( :exists? ).and_return( true )
        allow( YAML ).to receive( :load_file ).and_return( fog_file_contents )

        expect( VsphereHelper.load_config ).to be === vInfo

      end

      it 'raises an error when the .fog file is missing' do
        allow( File ).to receive( :exists? ).and_return( false )

        expect{ VsphereHelper.load_config }.to raise_error( ArgumentError )

      end

    end

   describe "#find_snapshot" do
     it 'can find a given snapshot name' do
       mockvm = MockRbVmomiVM.new( 'mockvm', snaplist )

       expect( vsphere_helper.find_snapshot( mockvm, 'snap2' ) ).to be === mockvm.get_snapshot( 'snap2' )

     end

   end

   describe "#find_customization" do
     it 'returns the customization spec' do

       expect( vsphere_helper.find_customization( 'name' ) ).to be === true

     end

   end

   describe "#find_vms" do
     it 'finds the list of vms' do
       connection = vsphere_helper.instance_variable_get( :@connection )
       connection.set_info( vms )

       expect( vsphere_helper.find_vms( 'mockvm1' ) ).to be === {vms[0].name => vms[0]}
     end

     it 'returns {} when no vm is found' do
       connection = vsphere_helper.instance_variable_get( :@connection )
       connection.set_info( vms )

       expect( vsphere_helper.find_vms( 'novm' ) ).to be === {}
     end

   end

   describe "#find_datastore" do
     it 'finds the datastore from the connection object' do
       connection = vsphere_helper.instance_variable_get( :@connection )
       dc = connection.serviceInstance.find_datacenter('testdc')
       expect(vsphere_helper.find_datastore( dc,'datastorename' ) ).to be === true
     end

   end

   describe "#find_folder" do
     it 'can find a folder in the datacenter' do
       connection = vsphere_helper.instance_variable_get( :@connection )
       expect(vsphere_helper.find_folder( 'testdc','root' ) ).to be === connection.serviceInstance.find_datacenter('testdc').vmFolder
     end

   end

   describe "#find_pool" do
     it 'can find a pool in a folder in the datacenter' do
       connection = vsphere_helper.instance_variable_get( :@connection )
       dc = connection.serviceInstance.find_datacenter('testdc')
       dc.hostFolder = MockRbVmomi::VIM::Folder.new
       dc.hostFolder.name = "/root"

       expect(vsphere_helper.find_pool( 'testdc','root' ) ).to be === connection.serviceInstance.find_datacenter('testdc').hostFolder

     end
     it 'can find a pool in a clustercomputeresource in the datacenter' do
       connection = vsphere_helper.instance_variable_get( :@connection )
       dc = connection.serviceInstance.find_datacenter('testdc')
       dc.hostFolder = MockRbVmomi::VIM::ClusterComputeResource.new
       dc.hostFolder.name = "/root"

       expect(vsphere_helper.find_pool( 'testdc','root' ) ).to be === connection.serviceInstance.find_datacenter('testdc').hostFolder
     end
     it 'can find a pool in a resourcepool in the datacenter' do
       connection = vsphere_helper.instance_variable_get( :@connection )
       dc = connection.serviceInstance.find_datacenter('testdc')
       dc.hostFolder = MockRbVmomi::VIM::ResourcePool.new
       dc.hostFolder.name = "/root"

       expect(vsphere_helper.find_pool( 'testdc','root' ) ).to be === connection.serviceInstance.find_datacenter('testdc').hostFolder
     end

   end

   describe "#wait_for_tasks" do
     it "can wait for tasks to error" do
       allow( vsphere_helper ).to receive( :sleep ).and_return( true )
       vms.each do |vm|
         vm.info.state = 'error'
       end

       expect(vsphere_helper.wait_for_tasks( vms, 0, 5 ) ).to be === vms
     end

     it "can wait for tasks to succeed" do
       allow( vsphere_helper ).to receive( :sleep ).and_return( true )
       vms.each do |vm|
         vm.info.state = 'success'
       end

       expect(vsphere_helper.wait_for_tasks( vms, 0, 5 ) ).to be === vms
     end

     it "errors when tasks fail to error/success before timing out" do
       allow( vsphere_helper ).to receive( :sleep ).and_return( true )
       vms.each do |vm|
         vm.info.state = 'nope'
       end

       expect{ vsphere_helper.wait_for_tasks( vms, 0, 5 ) }.to raise_error
     end

   end

   describe "#close" do
     it 'closes the connection' do
       connection = vsphere_helper.instance_variable_get( :@connection )
       expect( connection ).to receive( :close ).once
       
       vsphere_helper.close
     end
   end

 end
end
