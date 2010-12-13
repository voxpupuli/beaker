# SCP file to host
require 'lib/action'

class ScpFile < Action
  def do_scp(source, target)
    do_action(source,target) { |result,options|
      # Net::Scp always returns 0, so just set the return code to 0
      # Setting these values allows reporting via 
      # result.log(test_name)
      result.stdout = "SCP'ed file #{source} to #{@host}:#{target}"
      result.stderr=nil
      result.exit_code=0
	
      Net::SCP.start("#{@host}", "root", options) { |scp|
        scp.upload!("#{source}", "#{target}")
      }
    }
  end
end
