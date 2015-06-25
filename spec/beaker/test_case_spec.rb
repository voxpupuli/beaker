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
    end

    context 'metadata' do
      it 'sets the filename correctly from the path' do
        answer = 'jacket'
        path = "#{answer}.rb"
        File.open(path, 'w') do |f|
          f.write ""
        end
        @path = path
        testcase.run_test
        metadata = testcase.instance_variable_get(:@metadata)
        expect(metadata[:case][:file_name]).to be === answer
      end

      it 'resets the step name' do
        path = 'test.rb'
        File.open(path, 'w') do |f|
          f.write ""
        end
        @path = path
        # we have to create a TestCase by hand, so that we can set old
        tc = TestCase.new({}, logger, {}, path)
        # metadata on it, so that we can test that it's being reset correctly
        old_metadata = { :step => { :name => 'CharlieBrown' } }
        tc.instance_variable_set(:@metadata, old_metadata)
        tc.run_test
        metadata = tc.instance_variable_get(:@metadata)
        expect(metadata[:step][:name]).to be_nil
      end
    end

  end
end
