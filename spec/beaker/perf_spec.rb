require 'spec_helper'

module Beaker
  describe Perf do

    context "When a Perf object is created" do
      it 'creates a new Perf object' do
        hosts = Array.new
        options = Hash.new
        options[:log_level] = :debug
        my_logger = Beaker::Logger.new(options)
        perf = Perf.new( hosts, options, my_logger )
        expect( perf ).to be_a_kind_of Perf
      end

      it 'creates a new Perf object with a single host' do
        hosts = [ FakeHost.new ]
        options = Hash.new
        options[:log_level] = :debug
        my_logger = Beaker::Logger.new(options)
        perf = Perf.new( hosts, options, my_logger )
        expect( perf ).to be_a_kind_of Perf
      end

      it 'creates a new Perf object with multiple hosts' do
        hosts = [ FakeHost.new, FakeHost.new ]
        options = Hash.new
        options[:log_level] = :debug
        my_logger = Beaker::Logger.new(options)
        perf = Perf.new( hosts, options, my_logger )
        expect( perf ).to be_a_kind_of Perf
      end

      before(:each) do
        @options = make_opts
        @options[:collect_perf_data] = true
        @options[:log_level] = :debug
        @options[:color] = false
        @my_io = StringIO.new
        @my_logger = Beaker::Logger.new(@options)
        @my_logger.add_destination(@my_io)
      end

      it 'creates a new Perf object with a single host, :collect_perf_data = true' do
        hosts = [ make_host("myHost", @options) ]
#        @my_logger.remove_destination(STDOUT)
        perf = Perf.new( hosts, @options, @my_logger )
        expect( perf ).to be_a_kind_of Perf
        expect(@my_io.string).to match(/Setup perf on host: myHost/)
      end

      it 'creates a new Perf object with multiple hosts, :collect_perf_data = true' do
        hosts = [ make_host("myHost", @options), make_host("myOtherHost", @options) ]
#        @my_logger.remove_destination(STDOUT)
        perf = Perf.new( hosts, @options, @my_logger )
        expect( perf ).to be_a_kind_of Perf
        expect(@my_io.string).to match(/Setup perf on host: myHost*Setup perf on host: myOtherHost/)
      end

      it 'creates a new Perf object with multiple hosts, :collect_perf_data = true, SLES' do
        hosts = [ make_host("myHost", @options), make_host("myOtherHost", @options) ]
        hosts[0]['platform'] = "SLES"
#        @my_logger.remove_destination(STDOUT)
        perf = Perf.new( hosts, @options, @my_logger )
        expect( perf ).to be_a_kind_of Perf
        expect(@my_io.string).to match(/Setup perf on host: myHostSetup perf on host: myOtherHost/)
      end
    end

    context "When testing is finished, :collect_perf_data = true" do
      before(:each) do
        @options = make_opts
        @options[:collect_perf_data] = true
        @options[:log_level] = :debug
        @options[:color] = false
        @hosts = [ make_host("myHost", @options), make_host("myOtherHost", @options) ]
        @my_io = StringIO.new
        @my_logger = Beaker::Logger.new(@options)
        @my_logger.add_destination(@my_io)
      end

      it "Does the Right Thing on Linux hosts" do
        @hosts[0]['platform'] = "centos"
#        @my_logger.remove_destination(STDOUT)
        perf = Perf.new( @hosts, @options, @my_logger )
        expect( perf ).to be_a_kind_of Perf
        perf.print_perf_info
        expect(@my_io.string).to match(/Setup perf on host: myHostSetup perf on host: myOtherHostGetting perf data for host: myHostGetting perf data for host: myOtherHost/)
      end

      it "Does the Right Thing on non-Linux hosts" do
        @hosts[0]['platform'] = "windows"
#        @my_logger.remove_destination(STDOUT)
        perf = Perf.new( @hosts, @options, @my_logger )
        expect( perf ).to be_a_kind_of Perf
        perf.print_perf_info
        expect(@my_io.string).to match(/Setup perf on host: myHostSetup perf on host: myOtherHostGetting perf data for host: myHostGetting perf data for host: myOtherHost/)
      end
    end

    context "When testing is finished, :collect_perf_data = nil" do
      before(:each) do
        @options = make_opts
        @options[:log_level] = :debug
        @options[:color] = false
        @hosts = [ make_host("myHost", @options), make_host("myOtherHost", @options) ]
        @my_io = StringIO.new
        @my_logger = Beaker::Logger.new(@options)
        @my_logger.add_destination(@my_io)
      end

      it "Does nothing on Linux hosts" do
        hosts = [ make_host("myHost", @options), make_host("myOtherHost", @options) ]
        hosts[0]['platform'] = "centos"
#        @my_logger.remove_destination(STDOUT)
        perf = Perf.new( hosts, @options, @my_logger )
        expect( perf ).to be_a_kind_of Perf
        perf.print_perf_info
        expect(@my_io.string).to be_empty
      end

      it "Does nothing on non-Linux hosts" do
        hosts = [ make_host("myHost", @options), make_host("myOtherHost", @options) ]
        hosts[0]['platform'] = "windows"
#        @my_logger.remove_destination(STDOUT)
        perf = Perf.new( hosts, @options, @my_logger )
        expect( perf ).to be_a_kind_of Perf
        perf.print_perf_info
        expect(@my_io.string).to be_empty
      end
    end

  end
end
