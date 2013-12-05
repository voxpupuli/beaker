[ 'repetition', 'error_handler', 'host_handler', 'timed', 'platform' ].each do |file|
  begin
    require "beaker/shared/#{file}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), 'shared', file))
  end
end
module Beaker
  module Shared
    include Beaker::Shared::ErrorHandler
    include Beaker::Shared::HostRoleParser
    include Beaker::Shared::Repetition
    include Beaker::Shared::Timed
    include Beaker::Shared::Platform
  end
end
include Beaker::Shared
