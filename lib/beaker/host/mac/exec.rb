module Mac::Exec
  include Beaker::CommandFactory

  def touch(file, abs=true)
    (abs ? '/usr/bin/touch' : 'touch') + " #{file}"
  end

  # Restarts the SSH service
  #
  # @return [Result] result of starting SSH service
  def ssh_service_restart
    launch_daemons_plist = '/System/Library/LaunchDaemons/ssh.plist'
    exec(Beaker::Command.new("launchctl unload #{launch_daemons_plist}"))
    exec(Beaker::Command.new("launchctl load #{launch_daemons_plist}"))
  end

  # Sets the PermitUserEnvironment setting & restarts the SSH service
  #
  # @api private
  # @return [Result] result of the command starting the SSH service
  #   (from {#ssh_service_restart})
  def ssh_permit_user_environment
    ssh_config_file = '/etc/sshd_config'
    ssh_config_file = '/private/etc/ssh/sshd_config' if /^osx-/.match?(self['platform'])

    exec(Beaker::Command.new("echo '\nPermitUserEnvironment yes' >> #{ssh_config_file}"))
    ssh_service_restart()
  end

  # Checks if selinux is enabled
  # selinux is not availble on OS X
  #
  # @return [Boolean] false
  def selinux_enabled?()
    false
  end

  # Update ModifiedDate on a file
  # @param [String] file Path to the file
  # @param [String] timestamp Timestamp to set
  def modified_at(file, timestamp = nil)
    require 'date'
    time = timestamp ? DateTime.parse("#{timestamp}") : DateTime.now
    timestamp = time.strftime('%Y%m%d%H%M')
    execute("touch -mt #{timestamp} #{file}")
  end
end
