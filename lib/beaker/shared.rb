[ 'repetition', 'error_handler', 'host_manager', 'timed', 'semvar', 'options_resolver', 'fog_file_parser'].each do |lib|
  require "beaker/shared/#{lib}"
end
module Beaker
  module Shared
    include Beaker::Shared::ErrorHandler
    include Beaker::Shared::HostManager
    include Beaker::Shared::Repetition
    include Beaker::Shared::Timed
    include Beaker::Shared::Semvar
    include Beaker::Shared::OptionsResolver
    include Beaker::Shared::FogFileParser
  end
end
include Beaker::Shared
