require 'spec_helper'
require 'fileutils'

module PuppetAcceptance
  describe TestSuite do

    context 'new', :use_fakefs => true do
      let(:test_dir) { 'tmp/tests' }

      let(:options)  { {:tests => create_files(@files)} }
      let(:rb_test)  { File.expand_path(test_dir + '/my_ruby_file.rb')    }
      let(:pl_test)  { File.expand_path(test_dir + '/my_perl_file.pl')    }
      let(:sh_test)  { File.expand_path(test_dir + '/my_shell_file.sh')   }

      it 'fails without test files' do
        expect { PuppetAcceptance::TestSuite.new 'name', 'hosts',
                  Hash.new, 'config', :stop_on_error }.to raise_error
      end

      it 'includes specific files as test file when explicitly passed' do
        @files = [ rb_test ]
        ts = PuppetAcceptance::TestSuite.new 'name', 'hosts', options,
                                             'config', :stop_on_error

        expect { ts.instance_variable_get(:@test_files).
                  include? rb_test }.to be_true
      end

      it 'includes only .rb files as test files when dir is passed' do
        create_files [ rb_test, pl_test, sh_test ]
        @files = [ test_dir ]

        ts = PuppetAcceptance::TestSuite.new 'name', 'hosts',
               options, 'config', :stop_on_error

        processed_files = ts.instance_variable_get :@test_files

        expect(processed_files).to include(rb_test)
        expect(processed_files).to_not include(sh_test)
        expect(processed_files).to_not include(pl_test)
      end
    end
  end
end
