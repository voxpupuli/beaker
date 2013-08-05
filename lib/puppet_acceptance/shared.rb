[ 'repetition', 'error_handler', 'host_handler' ].each do |file|
  begin
    require "puppet_acceptance/shared/#{file}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), 'shared', file))
  end
end
module PuppetAcceptance
  module Shared
    include PuppetAcceptance::Shared::ErrorHandler
    include PuppetAcceptance::Shared::HostHandler
    include PuppetAcceptance::Shared::Repetition
  end
end
include PuppetAcceptance::Shared
