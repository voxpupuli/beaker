# Read Config file
# Accept filename as arg
# Return config object

class ParseConfig
  attr_accessor :filename
  def initialize(filename)
      self.filename = filename
  end

  class Config
    attr_accessor :host_list
    def initialize(host_list={})
      self.host_list = host_list
    end
  end

  # Create hash of hostname => role
  def read_cfg
    config = Config.new
    File.open("#{$work_dir}/#{filename}") do |file|
      while line = file.gets
        #next if /^#/
        if /^(PMASTER):\w+:(\S+)/ =~ line then
          config.host_list[$2] = $1
          puts "Puppet Master: #{$1}"
        end
        if /^(AGENT):\w+:(\S+)/ =~ line then
          config.host_list[$2] = $1
          puts "Puppet Agent: #{$1}"
        end
      end
    end
    return config
  end
end
