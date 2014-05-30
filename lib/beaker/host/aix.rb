[ 'host', 'command_factory' ].each do |lib|
    require "beaker/#{lib}"
end

module Aix
  class Host < Unix::Host
    [ 'user', 'group', 'file' ].each do |lib|
        require "beaker/host/aix/#{lib}"
    end

    include Aix::User
    include Aix::Group
    include Aix::File

  end
end
