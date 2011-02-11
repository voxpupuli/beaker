# This class is for testing Augeas functionality

class puppet_system_test::augeas {

  $sshd_config_path = "/etc/ssh/sshd_config"

  augeas { "sshd_config":
    changes => [ "set /files/${sshd_config_path}/PermitEmptyPasswords yes", ],
  }
}
