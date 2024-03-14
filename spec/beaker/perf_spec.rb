require 'spec_helper'

module Beaker
  describe Perf do
    context "When a Perf object is created" do
      before do
        @options = make_opts
        @options[:collect_perf_data] = 'normal'
        @options[:log_level] = :debug
        @options[:color] = false
        @my_io = StringIO.new
        @my_logger = Beaker::Logger.new(@options)
        @my_logger.add_destination(@my_io)
        @options[:logger] = @my_logger
      end

      it 'creates a new Perf object' do
        hosts = []
        options = {}
        options[:log_level] = :debug
        my_logger = Beaker::Logger.new(options)
        options[:logger] = my_logger
        perf = described_class.new(hosts, options)
        expect(perf).to be_a described_class
      end

      it 'creates a new Perf object with a single host' do
        hosts = [make_host("myHost", @options.merge('platform' => 'centos-6-64'))]
        @my_logger.remove_destination(STDOUT)
        perf = described_class.new(hosts, @options)
        expect(perf).to be_a described_class
        expect(@my_io.string).to eq("Setup perf on host: myHost\n")
      end

      it 'creates a new Perf object with multiple hosts' do
        hosts = [
          make_host("myHost", @options.merge('platform' => 'centos-6-64')),
          make_host("myOtherHost", @options.merge('platform' => 'centos-6-64')),
        ]
        @my_logger.remove_destination(STDOUT)
        perf = described_class.new(hosts, @options)
        expect(perf).to be_a described_class
        expect(@my_io.string).to eq("Setup perf on host: myHost\nSetup perf on host: myOtherHost\n")
      end

      it 'creates a new Perf object with multiple hosts, SLES' do
        hosts = [
          make_host("myHost", @options.merge('platform' => 'centos-6-64')),
          make_host("myOtherHost", @options.merge('platform' => 'sles-11-64')),
          make_host("myThirdHost", @options.merge('platform' => 'opensuse-15-64')),
        ]
        @my_logger.remove_destination(STDOUT)
        perf = described_class.new(hosts, @options)
        expect(perf).to be_a described_class
        expect(@my_io.string).to include("Setup perf on host: myHost\nSetup perf on host: myOtherHost\n")
      end
    end

    context "When testing is finished" do
      before do
        @options = make_opts
        @options[:collect_perf_data] = 'normal'
        @options[:log_level] = :debug
        @options[:color] = false
        @my_io = StringIO.new
        @my_logger = Beaker::Logger.new(@options)
        @my_logger.add_destination(@my_io)
        @options[:logger] = @my_logger
      end

      it "Does the Right Thing on Linux hosts" do
        hosts = [make_host("myHost", @options.merge('platform' => 'centos-6-64'))]
        @my_logger.remove_destination(STDOUT)
        perf = described_class.new(hosts, @options)
        expect(perf).to be_a described_class
        perf.print_perf_info
        expect(@my_io.string).to eq("Setup perf on host: myHost\nGetting perf data for host: myHost\n")
      end

      it "Does the Right Thing on non-Linux hosts" do
        hosts = [
          make_host("myHost", @options.merge('platform' => 'windows-11-64')),
          make_host("myOtherHost", @options.merge('platform' => 'solaris-11-64')),
        ]
        @my_logger.remove_destination(STDOUT)
        perf = described_class.new(hosts, @options)
        expect(perf).to be_a described_class
        perf.print_perf_info
        expect(@my_io.string).to eq("Setup perf on host: myHost\nPerf (sysstat) not supported on host: myHost\nSetup perf on host: myOtherHost\nPerf (sysstat) not supported on host: myOtherHost\nGetting perf data for host: myHost\nPerf (sysstat) not supported on host: myHost\nGetting perf data for host: myOtherHost\nPerf (sysstat) not supported on host: myOtherHost\n")
      end
    end
  end
end
