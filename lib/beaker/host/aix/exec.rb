module Aix::Exec
  include Beaker::CommandFactory

  def reboot
    exec(Beaker::Command.new("shutdown -Fr"), :expect_connection_failure => true)
  end

  def get_ip
    execute("ifconfig -a inet| awk '/broadcast/ {print $2}' | cut -d/ -f1 | head -1").strip
  end

  # Restarts the SSH service
  #
  # @return [Result] result of starting ssh service
  def ssh_service_restart
    exec(Beaker::Command.new("stopsrc -g ssh"))
    exec(Beaker::Command.new("startsrc -g ssh"))
  end

  # Sets the PermitUserEnvironent setting & restarts the SSH service
  #
  # @api private
  # @return [Result] result of the command starting the SSH service
  #   (from {#ssh_service_restart}).
  def ssh_permit_user_environment
    exec(Beaker::Command.new("echo '\nPermitUserEnvironment yes' >> /etc/ssh/sshd_config"))
    ssh_service_restart()
  end
end
