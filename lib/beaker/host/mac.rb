[ 'host', 'command_factory', 'command', 'options' ].each do |lib|
  require "beaker/#{lib}"
end

module Mac
    class Host < Unix::Host

    [ 'exec', 'user', 'group', 'pkg' ].each do |lib|
      require "beaker/host/mac/#{lib}"
    end

    include Mac::Exec
    include Mac::User
    include Mac::Group
    include Mac::Pkg

    def platform_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'             => 'root',
        'group'            => 'root',
        'pathseparator'    => ':',
      })
    end

    attr_reader :external_copy_base
    def initialize name, host_hash, options
      super

      @external_copy_base = '/var/root'
    end

  end
end
