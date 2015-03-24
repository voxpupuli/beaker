[ 'repetition', 'error_handler', 'host_manager', 'timed', 'semvar' ].each do |lib|
  require "beaker/shared/#{lib}"
end
module Beaker
  module Shared
    include Beaker::Shared::ErrorHandler
    include Beaker::Shared::HostManager
    include Beaker::Shared::Repetition
    include Beaker::Shared::Timed
    include Beaker::Shared::Semvar
  end
end
include Beaker::Shared
