[ 'host', 'command_factory', 'command', 'options' ].each do |lib|
      require "beaker/#{lib}"
end

module Unix
  class Host < Beaker::Host
    [ 'user', 'group', 'exec', 'pkg', 'file' ].each do |lib|
          require "beaker/host/unix/#{lib}"
    end

    include Unix::User
    include Unix::Group
    include Unix::File
    include Unix::Exec
    include Unix::Pkg

    def platform_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'             => 'root',
        'group'            => 'root',
        'pathseparator'    => ':',
      })
    end

    # Determines which SSH Server is in use on this host
    #
    # @note This method is mostly a placeholder method, since only :openssh
    #   can be returned at this time. Checkout {Windows::Host#determine_ssh_server}
    #   for an example where work needs to be done to determine the answer
    #
    # @return [Symbol] Value for the SSH Server in use
    def determine_ssh_server
      :openssh
    end

    attr_reader :external_copy_base
    def initialize name, host_hash, options
      super

      @external_copy_base = '/root'
    end

  end
end
