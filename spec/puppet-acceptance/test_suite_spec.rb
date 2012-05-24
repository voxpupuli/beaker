require 'spec_helper'

module PuppetAcceptance
  describe TestSuite do

    context '.new' do
      include FakeFS::SpecHelpers

      before do
        @test_dir = 'tmp/tests'
        Dir.mkdir_p @test_dir
        File.new "#{@test_dir}/test_file.rb", 'w+'
      end

      it 'instantiates' do
        options = {}
        options[:tests] = 'tmp/tests'
        ts = PuppetAcceptance::TestSuite.new('name', 'hosts', options, 'config', :stop_on_error)
      end

      it 'includes specific files as test file when explicitly passed' do
        options = {}
        options[:tests] = [ 'tmp/tests/my_ruby_file.rb',
                            'tmp/tests/my_shell_file.sh',
                            'tmp/tests/my_perl_file.pl' ]
        options[:tests].each do |my_file|
          File.new my_file, 'w'
        end
        ts = PuppetAcceptance::TestSuite.new('name', 'hosts', options, 'config', :stop_on_error)
        files = ts.instance_variable_get :@test_files
        options[:tests].each do |my_file|
          (files.include? my_file).should be_true
        end
      end

      it 'includes only .rb files as test files when dir is passed' do
        options = {:tests => 'tmp/tests'}
        tests = [ 'tmp/tests/my_ruby_file.rb',
                  'tmp/tests/my_shell_file.sh',
                  'tmp/tests/my_perl_file.pl' ]

        tests.each_with_index do |my_file, i|
          File.new my_file, 'w'
          tests[i] = File.expand_path my_file
        end

        ts = PuppetAcceptance::TestSuite.new('name', 'hosts', options, 'config', :stop_on_error)
        files = ts.instance_variable_get :@test_files
        (files.include? tests[0]).should be_true
        (files.include? 'tmp/tests/my_shell_file.sh').should be_false
        (files.include? 'tmp/tests/my_perl_file.pl').should be_false
      end

      it 'fails without test files' do
        ts = PuppetAcceptance::TestSuite.new('name', 'hosts', options, 'config', :stop_on_error)
    end
  end
end
