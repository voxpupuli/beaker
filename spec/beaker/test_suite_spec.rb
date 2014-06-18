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

    describe TestSuite::TestSuiteResult do

      let( :options )           { make_opts.merge({ :logger => double().as_null_object }) }
      let( :hosts )             { make_hosts() }
      let( :testcase1 )         { Beaker::TestCase.new( hosts, options[:logger], options) }
      let( :testcase2 )         { Beaker::TestCase.new( hosts, options[:logger], options) }
      let( :testcase3 )         { Beaker::TestCase.new( hosts, options[:logger], options) }
      let( :test_suite_result ) { TestSuite::TestSuiteResult.new( options, "my_suite") }

      it 'supports adding test cases' do
        expect( test_suite_result.test_count ).to be === 0
        test_suite_result.add_test_case( testcase1 )
        expect( test_suite_result.test_count ).to be === 1
      end

      it 'calculates passed tests' do
        testcase1.instance_variable_set(:@test_status, :pass)
        testcase2.instance_variable_set(:@test_status, :pass)
        testcase3.instance_variable_set(:@test_status, :fail)
        test_suite_result.add_test_case( testcase1 )
        test_suite_result.add_test_case( testcase2 )
        test_suite_result.add_test_case( testcase3 )
        expect( test_suite_result.passed_tests ).to be == 2
      end

      it 'calculates failed tests' do
        testcase1.instance_variable_set(:@test_status, :pass)
        testcase2.instance_variable_set(:@test_status, :pass)
        testcase3.instance_variable_set(:@test_status, :fail)
        test_suite_result.add_test_case( testcase1 )
        test_suite_result.add_test_case( testcase2 )
        test_suite_result.add_test_case( testcase3 )
        expect( test_suite_result.failed_tests ).to be == 1
      end

      it 'calculates errored tests' do
        testcase1.instance_variable_set(:@test_status, :error)
        testcase2.instance_variable_set(:@test_status, :pass)
        testcase3.instance_variable_set(:@test_status, :fail)
        test_suite_result.add_test_case( testcase1 )
        test_suite_result.add_test_case( testcase2 )
        test_suite_result.add_test_case( testcase3 )
        expect( test_suite_result.errored_tests ).to be == 1
      end

      it 'calculates skipped tests' do
        testcase1.instance_variable_set(:@test_status, :error)
        testcase2.instance_variable_set(:@test_status, :skip)
        testcase3.instance_variable_set(:@test_status, :fail)
        test_suite_result.add_test_case( testcase1 )
        test_suite_result.add_test_case( testcase2 )
        test_suite_result.add_test_case( testcase3 )
        expect( test_suite_result.skipped_tests ).to be == 1
      end

      it 'calculates pending tests' do
        testcase1.instance_variable_set(:@test_status, :error)
        testcase2.instance_variable_set(:@test_status, :pending)
        testcase3.instance_variable_set(:@test_status, :fail)
        test_suite_result.add_test_case( testcase1 )
        test_suite_result.add_test_case( testcase2 )
        test_suite_result.add_test_case( testcase3 )
        expect( test_suite_result.pending_tests ).to be == 1
      end

      it 'calculates sum_failed as a sum of errored and failed TestCases' do
        testcase1.instance_variable_set(:@test_status, :error)
        testcase2.instance_variable_set(:@test_status, :pending)
        testcase3.instance_variable_set(:@test_status, :fail)
        test_suite_result.add_test_case( testcase1 )
        test_suite_result.add_test_case( testcase2 )
        test_suite_result.add_test_case( testcase3 )
        expect( test_suite_result.sum_failed ).to be == 2
      end

      it 'reports success with no errors/failures' do
        testcase1.instance_variable_set(:@test_status, :pass)
        testcase2.instance_variable_set(:@test_status, :pending)
        testcase3.instance_variable_set(:@test_status, :fail)
        test_suite_result.add_test_case( testcase1 )
        test_suite_result.add_test_case( testcase2 )
        test_suite_result.add_test_case( testcase3 )
        expect( test_suite_result.success? ).to be == false
      end

      it 'reports failed if any tests error/fail' do
        testcase1.instance_variable_set(:@test_status, :pass)
        testcase2.instance_variable_set(:@test_status, :pending)
        testcase3.instance_variable_set(:@test_status, :fail)
        test_suite_result.add_test_case( testcase1 )
        test_suite_result.add_test_case( testcase2 )
        test_suite_result.add_test_case( testcase3 )
        expect( test_suite_result.failed? ).to be == true
      end

      it 'can calculate the sum of all TestCase runtimes' do
        testcase1.instance_variable_set(:@runtime, 1)
        testcase2.instance_variable_set(:@runtime, 10)
        testcase3.instance_variable_set(:@runtime, 100)
        test_suite_result.add_test_case( testcase1 )
        test_suite_result.add_test_case( testcase2 )
        test_suite_result.add_test_case( testcase3 )
        expect( test_suite_result.elapsed_time ).to be == 111
      end


    end
  end
end
