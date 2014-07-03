[ 'repetition', 'error_handler', 'host_role_parser', 'timed' ].each do |lib|
  require "beaker/shared/#{lib}"
end
module Beaker
  module Shared
    include Beaker::Shared::ErrorHandler
    include Beaker::Shared::HostRoleParser
    include Beaker::Shared::Repetition
    include Beaker::Shared::Timed
  end
end
include Beaker::Shared
