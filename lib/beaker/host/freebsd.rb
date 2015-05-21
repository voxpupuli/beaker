[ 'host', 'command_factory' ].each do |lib|
  require "beaker/#{lib}"
end

module FreeBSD
  class Host < Unix::Host

    [
      'exec',
    ].each do |lib|
        require "beaker/host/freebsd/#{lib}"
    end

    include FreeBSD::Exec

    def platform_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'              => 'root',
        'group'             => 'root',
        'pathseparator'     => ':',
        })
    end

  end

end
