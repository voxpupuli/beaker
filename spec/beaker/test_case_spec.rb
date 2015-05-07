require 'spec_helper'

module Beaker
  describe TestCase do
    let(:logger) {  double('logger').as_null_object }
    let(:path) { @path || '/tmp/nope' }
    let(:testcase) { TestCase.new({}, logger, {}, path) }

    context 'run_test' do
      it 'defaults to test_status :pass on success' do
        path = 'test.rb'
        File.open(path, 'w') do |f|
          f.write ""
        end
        @path = path
        expect( testcase ).to_not receive( :log_and_fail_test )
        testcase.run_test
        status = testcase.instance_variable_get(:@test_status)
        expect(status).to be === :pass
      end

      it 'updates test_status to :skip on SkipTest' do
        path = 'test.rb'
        File.open(path, 'w') do |f|
          f.write "raise SkipTest"
        end
        @path = path
        expect( testcase ).to_not receive( :log_and_fail_test )
        testcase.run_test
        status = testcase.instance_variable_get(:@test_status)
        expect(status).to be === :skip
      end

      it 'updates test_status to :pending on PendingTest' do
        path = 'test.rb'
        File.open(path, 'w') do |f|
          f.write "raise PendingTest"
        end
        @path = path
        expect( testcase ).to_not receive( :log_and_fail_test )
        testcase.run_test
        status = testcase.instance_variable_get(:@test_status)
        expect(status).to be === :pending
      end

      it 'updates test_status to :fail on FailTest' do
        path = 'test.rb'
        File.open(path, 'w') do |f|
          f.write "raise FailTest"
        end
        @path = path
        expect( testcase ).to_not receive( :log_and_fail_test )
        testcase.run_test
        status = testcase.instance_variable_get(:@test_status)
        expect(status).to be === :fail
      end

      it 'correctly handles RuntimeError' do
        path = 'test.rb'
        File.open(path, 'w') do |f|
          f.write "raise RuntimeError"
        end
        @path = path
        expect( testcase ).to receive( :log_and_fail_test ).once.with(kind_of(RuntimeError))
        testcase.run_test
      end

      it 'correctly handles ScriptError' do
        path = 'test.rb'
        File.open(path, 'w') do |f|
          f.write "raise ScriptError"
        end
        @path = path
        expect( testcase ).to receive( :log_and_fail_test ).once.with(kind_of(ScriptError))
        testcase.run_test
      end

      it 'correctly handles Timeout::Error' do
        path = 'test.rb'
        File.open(path, 'w') do |f|
          f.write "raise Timeout::Error"
        end
        @path = path
        expect( testcase ).to receive( :log_and_fail_test ).once.with(kind_of(Timeout::Error))
        testcase.run_test
      end

      it 'correctly handles CommandFailure' do
        path = 'test.rb'
        File.open(path, 'w') do |f|
          f.write "raise Host::CommandFailure"
        end
        @path = path
        expect( testcase ).to receive( :log_and_fail_test ).once.with(kind_of(Host::CommandFailure))
        testcase.run_test
      end

      it 'sets @file_name correctly from the @path' do
        file_name = 'test_150505_greatest_of_days'
        path = "#{file_name}.rb"
        File.open(path, 'w') do |f|
          f.write ""
        end
        @path = path
        expect( testcase ).to_not receive( :log_and_fail_test )
        testcase.run_test
        name_to_test = testcase.instance_variable_get(:@file_name)
        expect( name_to_test ).to be === file_name
      end

      it 'sets :current_test_info' do
        file_name = 'test_150505_greatest_of_nights'
        path = "#{file_name}.rb"
        File.open(path, 'w') do |f|
          f.write ""
        end
        @path = path
        expect( testcase ).to_not receive( :log_and_fail_test )
        testcase.run_test
        opts = testcase.instance_variable_get(:@options)
        expect( opts[:current_test_info][:case][:file_name] ).to be === file_name
        expect( opts[:current_test_info][:case][:actual]    ).to be === testcase
        expect( opts[:current_test_info][:step][:name]      ).to be_nil
      end
    end

  end
end
