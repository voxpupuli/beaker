# Read Config file
# Accept filename as arg
# Return hash of hostname => role

class ParseConfig
  attr_accessor :filename
  def initialize(filename)
      self.filename = filename
  end

  class HostList
    attr_accessor :host_list
    def initialize(host_list={})
      self.host_list = host_list
    end
  end

  # Create hash of hostname => role
  def read_cfg
    hosts = HostList.new
    File.open("#{filename}") do |file|
      while line = file.gets
        #next if /^#/
        if /^(PMASTER):\w+:(\S+)/ =~ line then
          hosts.host_list[$2] = $1
        end
        if /^(AGENT):\w+:(\S+)/ =~ line then
          hosts.host_list[$2] = $1
        end
      end
    end
    return hosts
  end
end
