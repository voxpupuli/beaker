module Aix::Exec
  include Beaker::CommandFactory

  def get_ip
    execute("ifconfig -a inet| awk '/broadcast/ {print $2}' | cut -d/ -f1 | head -1").strip
  end
end
