[ 'host', 'command_factory', 'command', 'options', 'dsl/wrappers' ].each do |lib|
  require "beaker/#{lib}"
end

module PSWindows
  class Host < Beaker::Host
    [ 'user', 'group', 'exec', 'pkg', 'file' ].each do |lib|
      require "beaker/host/pswindows/#{lib}"
    end

    include PSWindows::User
    include PSWindows::Group
    include PSWindows::File
    include PSWindows::Exec
    include PSWindows::Pkg

    def platform_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'              => 'Administrator',
        'group'             => 'Administrators',
        'pathseparator'     => ';',
      })
    end

  end
end
