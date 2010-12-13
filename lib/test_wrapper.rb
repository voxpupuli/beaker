class TestWrapper
  attr_reader :config, :path, :fail_flag, :usr_home
  def initialize(config,path)
    @config = config
    @path = path
    @fail_flag = 0
    @usr_home = ENV['HOME']
    #
    # We put this on each wrapper (rather than the class) so that methods
    # defined in the tests don't leak out to other tests. 
    class << self
      def run_test
        test = File.read(path)
        eval test
        classes = test.split(/\n/).collect { |l| l[/^ *class +(\w+) *$/,1]}.compact
        case classes.length
        when 0; self
        when 1; eval(classes[0]).new(config)
        else fail "More than one class found in #{path}"
        end
      end
    end
  end
  def hosts(desired_role=nil)
    config["HOSTS"].
      keys.
      select { |host| 
        desired_role.nil? or config["HOSTS"][host]['roles'].any? { |role| role =~ desired_role }
      }
  end
  def agents
    hosts /agent/
  end
  def master
    masters = hosts /master/
    fail "There must be exactly one master" unless masters.length == 1
    masters.first
  end
  def dashboard
    dashboards = hosts /dashboard/
    fail "There must be exactly one dashboard" unless dashboards.length == 1
    dashboards.first
  end
end
