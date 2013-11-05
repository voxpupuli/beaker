[ 'repetition', 'error_handler', 'host_handler' ].each do |file|
  begin
    require "beaker/shared/#{file}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), 'shared', file))
  end
end
module Beaker
  module Shared
    include Beaker::Shared::ErrorHandler
    include Beaker::Shared::HostHandler
    include Beaker::Shared::Repetition
  end
end
include Beaker::Shared
