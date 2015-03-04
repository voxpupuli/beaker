class MockVcenterOrchestratorWorkflow
  attr_accessor :name, :id, :parameters
end

class MockVcenterOrchestratorHelper

  @@fog_file = {}

  def initialize vInfo, verify_ssl

  end

  def self.set_config conf
    @@fog_file = conf
  end

  def self.load_config file
    @@fog_file
  end

  def find_workflow wf, id
    url = nil
    @@wfs.each_key do |workflow|
      if workflow == wf
        url = wf
      end
    end

    if url
      return url
    else
      raise "Workflow not found"
    end
  end

  def self.set_wfs hosts
    @@wfs = {}
    hosts.each do |host|
      wf = MockVcenterOrchestratorWorkflow.new
      wf.name = host[:provision_workflow][:name]
      wf.parameters = host[:provision_workflow][:parameters]
      @@wfs[wf.name] = wf
      wf = MockVcenterOrchestratorWorkflow.new
      wf.name = host[:cleanup_workflow][:name]
      wf.parameters = host[:cleanup_workflow][:parameters]
      @@wfs[wf.name] = wf
    end
  end

  def run_workflow url, parameters
    parameters[:result]
  end
end