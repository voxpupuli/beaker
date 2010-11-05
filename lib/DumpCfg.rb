# Remote command execution
# Accpets host name a remote command to execute

class DumpCfg
  attr_accessor :hosts
  def initialize(hosts)
    self.hosts = hosts
  #end

  #def do_dump
    host=""
    os=""
    @hosts.host_list.each do |host, os|
      puts "#{host} #{os}"
    end
  end

end
