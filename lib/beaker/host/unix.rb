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

  end
end
