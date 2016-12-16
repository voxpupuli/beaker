# Ensure that `$LOAD_PATH` is set up properly, in cases where the entire
# acceptance suite is being run, but the options file
# `acceptance/config/acceptance_options.rb` was not specified via the
# `--options-file` command-line argument.
begin
  require 'helpers/test_helper'
rescue LoadError
  $LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
  require 'helpers/test_helper'
end
