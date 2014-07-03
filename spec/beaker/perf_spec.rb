require 'spec_helper'

module Beaker
  describe Perf do
    context "When a Perf object is created" do
      it 'creates a new Perf object' do
        hosts = Array.new
        options = Hash.new
        my_logger = "a logger"
        perf = Perf.new( hosts, options, my_logger )
        expect( perf ).to be_a_kind_of Perf
      end

      it 'creates a new Perf object with a single host' do
        hosts = [ FakeHost.new ]
        options = Hash.new
        my_logger = "a logger"
        perf = Perf.new( hosts, options, my_logger )
        expect( perf ).to be_a_kind_of Perf
      end

      it 'creates a new Perf object with multiple hosts' do
        hosts = [ FakeHost.new, FakeHost.new ]
        options = Hash.new
        my_logger = "a logger"
        perf = Perf.new( hosts, options, my_logger )
        expect( perf ).to be_a_kind_of Perf
      end

      it 'creates a new Perf object with a single host, :collect_perf_data = true' do
        options = make_opts
        options[:collect_perf_data] = true
        hosts = [ make_host("myHost", options) ]
        my_logger = logger
        perf = Perf.new( hosts, options, my_logger )
        expect( perf ).to be_a_kind_of Perf
      end

      it 'creates a new Perf object with multiple hosts, :collect_perf_data = true' do
        options = make_opts
        options[:collect_perf_data] = true
        hosts = [ make_host("myHost", options), make_host("myOtherHost", options) ]
        my_logger = logger
        perf = Perf.new( hosts, options, my_logger )
        expect( perf ).to be_a_kind_of Perf
      end

      it 'creates a new Perf object with multiple hosts, :collect_perf_data = true, SLES' do
        options = make_opts
        options[:collect_perf_data] = true
        hosts = [ make_host("myHost", options), make_host("myOtherHost", options) ]
        hosts[0]['platform'] = "SLES"
        my_logger = logger
        perf = Perf.new( hosts, options, my_logger )
        expect( perf ).to be_a_kind_of Perf
      end
    end

    context "When testing is finished, :collect_perf_data = true" do
      it "Does the Right Thing on Linux hosts" do
        options = make_opts
        options[:collect_perf_data] = true
        hosts = [ make_host("myHost", options), make_host("myOtherHost", options) ]
        hosts[0]['platform'] = "centos"
        my_logger = logger
        perf = Perf.new( hosts, options, my_logger )
        expect( perf ).to be_a_kind_of Perf
        perf.print_perf_info
      end

      it "Does the Right Thing on non-Linux hosts" do
        options = make_opts
        options[:collect_perf_data] = true
        hosts = [ make_host("myHost", options), make_host("myOtherHost", options) ]
        hosts[0]['platform'] = "windows"
        my_logger = logger
        perf = Perf.new( hosts, options, my_logger )
        expect( perf ).to be_a_kind_of Perf
        perf.print_perf_info
      end
    end

    context "When testing is finished, :collect_perf_data = false" do
      it "Does nothing on Linux hosts" do
        options = make_opts
        hosts = [ make_host("myHost", options), make_host("myOtherHost", options) ]
        hosts[0]['platform'] = "centos"
        my_logger = logger
        perf = Perf.new( hosts, options, my_logger )
        expect( perf ).to be_a_kind_of Perf
        perf.print_perf_info
      end

      it "Does nothing on non-Linux hosts" do
        options = make_opts
        hosts = [ make_host("myHost", options), make_host("myOtherHost", options) ]
        hosts[0]['platform'] = "windows"
        my_logger = logger
        perf = Perf.new( hosts, options, my_logger )
        expect( perf ).to be_a_kind_of Perf
        perf.print_perf_info
      end
    end

  end
end
