require 'spec_helper'
require 'fileutils'

module Beaker
  module Runner
    module Native
      describe TestSuite do
        context 'new' do
          let(:test_dir) { 'tmp/tests' }
          let(:options)  { {'name' => create_files(@files)} }
          let(:rb_test)  { File.expand_path(test_dir + '/my_ruby_file.rb')    }
          let(:pl_test)  { File.expand_path(test_dir + '/my_perl_file.pl')    }
          let(:sh_test)  { File.expand_path(test_dir + '/my_shell_file.sh')   }

          it 'fails without test files' do
            expect { Beaker::Runner::Native::TestSuite.new('name', 'hosts', Hash.new, Time.now, :stop_on_error) }.to raise_error
          end

          it 'includes specific files as test file when explicitly passed' do
            @files = [ rb_test ]
            ts = Beaker::Runner::Native::TestSuite.new('name', 'hosts', options, Time.now, :stop_on_error)

            tfs = ts.instance_variable_get(:@test_files)
            expect(tfs).to include rb_test
          end

          it 'defaults to :slow fail_mode if not provided through parameter or options' do
            @files = [ rb_test ]
            ts = Beaker::Runner::Native::TestSuite.new('name', 'hosts', options, Time.now)
            tfm = ts.instance_variable_get(:@fail_mode)
            expect(tfm).to be == :slow
          end

          it 'uses provided parameter fail_mode' do
            @files = [ rb_test ]
            ts = Beaker::Runner::Native::TestSuite.new('name', 'hosts', options, Time.now, :fast)
            tfm = ts.instance_variable_get(:@fail_mode)
            expect(tfm).to be == :fast
          end

          it 'uses options fail_mode if fail_mode parameter is not provided' do
            @files = [ rb_test ]
            options[:fail_mode] = :fast
            ts = Beaker::Runner::Native::TestSuite.new('name', 'hosts', options, Time.now)
            tfm = ts.instance_variable_get(:@fail_mode)
            expect(tfm).to be == :fast
          end
        end

        context 'run' do
          let( :options )     { make_opts.merge({ :logger => double().as_null_object, 'name' => create_files(@files), :log_dated_dir => '.', :xml_dated_dir => '.'}) }
          let(:broken_script) { "raise RuntimeError" }
          let(:fail_script)   { "raise Beaker::DSL::FailTest" }
          let(:okay_script)   { "true" }
          let(:rb_test)       { 'my_ruby_file.rb'     }
          let(:pl_test)       { '/my_perl_file.pl'    }
          let(:sh_test)       { '/my_shell_file.sh'   }
          let(:hosts)         { make_hosts() }

          it 'fails fast if fail_mode != :slow and runtime error is raised' do
            allow( Logger ).to receive('new')
            @files = [ rb_test, pl_test, sh_test]
            File.open(rb_test, 'w') { |file| file.write(broken_script) }
            File.open(pl_test, 'w') { |file| file.write(okay_script) }
            File.open(sh_test, 'w') { |file| file.write(okay_script) }

            ts = Beaker::Runner::Native::TestSuite.new( 'name', hosts, options, Time.now, :stop )
            tsr = ts.instance_variable_get( :@test_suite_results )
            allow( tsr ).to receive(:write_junit_xml).and_return( true )
            allow( tsr ).to receive(:summarize).and_return( true )

            ts.run
            expect( tsr.errored_tests ).to be === 1
            expect( tsr.failed_tests ).to be === 0
            expect( tsr.test_count ).to be === 1
            expect( tsr.passed_tests).to be === 0
          end

          it 'fails fast if fail_mode != :slow and fail test is raised' do
            allow( Logger ).to receive('new')
            @files = [ rb_test, pl_test, sh_test]
            File.open(rb_test, 'w') { |file| file.write(fail_script) }
            File.open(pl_test, 'w') { |file| file.write(okay_script) }
            File.open(sh_test, 'w') { |file| file.write(okay_script) }

            ts = Beaker::Runner::Native::TestSuite.new( 'name', hosts, options, Time.now, :stop )
            tsr = ts.instance_variable_get( :@test_suite_results )
            allow( tsr ).to receive(:write_junit_xml).and_return( true )
            allow( tsr ).to receive(:summarize).and_return( true )

            ts.run
            expect( tsr.errored_tests ).to be === 0
            expect( tsr.failed_tests ).to be === 1
            expect( tsr.test_count ).to be === 1
            expect( tsr.passed_tests).to be === 0
          end

          it 'fails slow if fail_mode = :slow, even if a test fails and there is a runtime error' do
            allow( Logger ).to receive('new')
            @files = [ rb_test, pl_test, sh_test]
            File.open(rb_test, 'w') { |file| file.write(broken_script) }
            File.open(pl_test, 'w') { |file| file.write(fail_script) }
            File.open(sh_test, 'w') { |file| file.write(okay_script) }

            ts = Beaker::Runner::Native::TestSuite.new( 'name', hosts, options, Time.now, :slow )
            tsr = ts.instance_variable_get( :@test_suite_results )
            allow( tsr ).to receive(:write_junit_xml).and_return( true )
            allow( tsr ).to receive(:summarize).and_return( true )

            ts.run
            expect( tsr.errored_tests ).to be === 1
            expect( tsr.failed_tests ).to be === 1
            expect( tsr.test_count ).to be === 3
            expect( tsr.passed_tests).to be === 1
          end
        end

        describe TestSuite::TestSuiteResult do
          let( :options )           { make_opts.merge({ :logger => double().as_null_object }) }
          let( :hosts )             { make_hosts() }
          let( :testcase1 )         { Beaker::Runner::Native::TestCase.new( hosts, options[:logger], options) }
          let( :testcase2 )         { Beaker::Runner::Native::TestCase.new( hosts, options[:logger], options) }
          let( :testcase3 )         { Beaker::Runner::Native::TestCase.new( hosts, options[:logger], options) }
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

          describe '#write_junit_xml' do
            let( :options )     { make_opts.merge({ :logger => double().as_null_object, 'name' => create_files(@files), :log_dated_dir => '.', :xml_dated_dir => '.'}) }
            let(:rb_test)       { 'my_ruby_file.rb'     }

            it 'doesn\'t re-order test cases themselves on time_sort' do
              nokogiri_mock = Hash.new
              allow( nokogiri_mock ).to receive( :add_child )
              allow( Nokogiri::XML::Node ).to receive( :new ) { nokogiri_mock }
              allow( LoggerJunit ).to receive( :write_xml ).and_yield( Object.new, nokogiri_mock )

              @files = [ rb_test, rb_test, rb_test]
              ts = Beaker::Runner::Native::TestSuite.new( 'name', hosts, options, Time.now, :fast )
              tsr = ts.instance_variable_get( :@test_suite_results )

              allow( tsr ).to receive( :start_time ).and_return(0)
              allow( tsr ).to receive( :stop_time ).and_return(10)
              expect( tsr.instance_variable_get( :@logger ) ).to receive( :error ).never

              test_cases = []
              3.times do
                tc = Beaker::Runner::Native::TestCase.new( hosts, options[:logger], options, rb_test)
                allow( tc ).to receive( :sublog ).and_return( false )
                test_cases << tc
              end
              test_cases[0].instance_variable_set(:@runtime, 3)
              test_cases[1].instance_variable_set(:@runtime, 301)
              test_cases[2].instance_variable_set(:@runtime, 101)
              test_cases.map { |tc| tsr.add_test_case( tc ) }

              original_testcase_order = test_suite_result.instance_variable_get( :@test_cases ).dup
              tsr.write_junit_xml( 'fakeFilePath07', 'fakeFileToLink09', true )
              after_testcase_order = test_suite_result.instance_variable_get( :@test_cases ).dup
              expect( after_testcase_order ).to be === original_testcase_order
            end
          end
        end

        describe '#log_path' do
          let( :sh_test   ) { '/my_shell_file.sh'   }
          let( :files     ) { @files ? @files : [sh_test] }
          let( :options   ) { make_opts.merge({ :logger => double().as_null_object, 'name' => create_files(files) }) }
          let( :hosts     ) { make_hosts() }
          let( :testsuite ) { Beaker::Runner::Native::TestSuite.new( 'name', hosts, options, Time.now, :stop ) }

          it 'returns the simple joining of the log dir & file as required' do
            expect(testsuite.log_path('foo.txt', 'man/date')).to be === 'man/date/foo.txt'
          end

          describe 'builds the base directory correctly' do
            # the base directory is where the latest symlink itself should live
            it 'in the usual case' do
              expect( File.symlink?('man/latest') ).to be_falsy
              testsuite.log_path('foo.txt', 'man/date')
              expect( File.symlink?('man/latest') ).to be_truthy
            end

            it 'if given a nested directory' do
              expect( File.symlink?('a/latest') ).to be_falsy
              testsuite.log_path('foo.txt', 'a/b/c/d/e/f')
              expect( File.symlink?('a/latest') ).to be_truthy
            end
          end

          describe 'builds the symlink directory correctly' do
            # the symlink directory is where the symlink points to
            it 'in the usual case' do
              expect( File.symlink?('d/latest') ).to be_falsy
              testsuite.log_path('foo.txt', 'd/e')
              expect( File.readlink('d/latest') ).to be === 'e'
            end

            it 'if given a nested directory' do
              expect( File.symlink?('f/latest') ).to be_falsy
              testsuite.log_path('foo.txt', 'f/g/h/i/j/k')
              expect( File.readlink('f/latest') ).to be === 'g/h/i/j/k'
            end
          end
        end
      end
    end
  end
end
