module Aix
  class Host < Unix::Host
    include Aix::User
    include Aix::Group
    include Aix::File

  end
end
