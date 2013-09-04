require 'spec_helper'
require 'fileutils'

module Beaker
  describe TestSuite do

    context 'new', :use_fakefs => true do
      let(:test_dir) { 'tmp/tests' }

      let(:options)  { {'name' => create_files(@files)} }
      let(:rb_test)  { File.expand_path(test_dir + '/my_ruby_file.rb')    }
      let(:pl_test)  { File.expand_path(test_dir + '/my_perl_file.pl')    }
      let(:sh_test)  { File.expand_path(test_dir + '/my_shell_file.sh')   }

      it 'fails without test files' do
        expect { Beaker::TestSuite.new 'name', 'hosts',
                  Hash.new, :stop_on_error }.to raise_error
      end

      it 'includes specific files as test file when explicitly passed' do
        @files = [ rb_test ]
        ts = Beaker::TestSuite.new 'name', 'hosts', options,
                                             :stop_on_error

        expect { ts.instance_variable_get(:@test_files).
                  include? rb_test }.to be_true
      end

    end
  end
end
