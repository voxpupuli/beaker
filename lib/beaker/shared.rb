module Beaker
  module Shared
    include Beaker::Shared::ErrorHandler
    include Beaker::Shared::HostRoleParser
    include Beaker::Shared::Repetition
    include Beaker::Shared::Timed
  end
end
include Beaker::Shared
