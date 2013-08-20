require File.expand_path(File.join(File.dirname(__FILE__), '..', 'host'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'command_factory'))

module Aix
  class Host < Unix::Host
    require File.expand_path(File.join(File.dirname(__FILE__), 'aix', 'user'))
    require File.expand_path(File.join(File.dirname(__FILE__), 'aix', 'group'))
    require File.expand_path(File.join(File.dirname(__FILE__), 'aix', 'file'))

    include Aix::User
    include Aix::Group
    include Aix::File

  end
end
