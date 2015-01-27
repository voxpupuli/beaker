require 'yaml' unless defined?(YAML)

module Beaker
  class VcenterOrchestrator < Beaker::Hypervisor
    def initialize(vco_hosts, options)
      @options = options
      @logger = options[:logger]
      @hosts = vco_hosts
    end

    def provision
      vco_vms = {}
      @hosts.each do |h|
        name = h["vmname"] || h.name
        vco_vms[name] = h["provision_workflow"]
      end

      self.execute_workflow(vco_vms)

    end

    def cleanup
      vco_vms = {}
      @hosts.each do |h|
        name = h["vmname"] || h.name
        vco_vms[name] = h["cleanup_workflow"]
      end

      self.execute_workflow(vco_vms)
    end

    def execute_workflow vco_vms
      vco_credentials = VcenterOrchestratorHelper.load_config(@options[:dot_fog])

      @options[:verify_ssl] = true if @options[:verify_ssl].nil?

      vco_helper = VcenterOrchestratorHelper.new( vco_credentials, @options[:verify_ssl] )

      vco_vms.each_pair do |name, wf|
        workflow = vco_helper.find_workflow(wf["name"], wf["id"])

        @logger.notify "Executing vCenter Orchestrator workflow"

        start = Time.now
        # This will block for each workflow run
        wf_return = vco_helper.run_workflow(workflow, vco_vms[name]["parameters"])

        time = Time.now - start
        @logger.notify "Spent %.2f seconds running workflow" % time

        if wf_return != "COMPLETED"
          raise "Vcenter Orchestrator Workflow run returned #{wf_return}, we expected it to return COMPLETED"
        end
      end
    end
  end
end