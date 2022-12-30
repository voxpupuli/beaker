# encoding: UTF-8
require 'spec_helper'

module Beaker
  describe NetworkManager do
    let( :mock_provisioning_logger ) {
      mock_provisioning_logger = Object.new
      allow( mock_provisioning_logger ).to receive( :notify )
      mock_provisioning_logger }
    let( :options ) {
      make_opts.merge({
        'logger' => double().as_null_object,
        :logger_sut => mock_provisioning_logger,
        :log_prefix => @log_prefix,
        :hosts_file => @hosts_file,
        :default_log_prefix => 'hello_default',
      })
    }
    let( :network_manager ) { described_class.new(options, options[:logger]) }
    let( :hosts ) { make_hosts }
    let( :host ) { hosts[0] }

    describe '#log_sut_event' do
      before do
        @log_prefix = 'log_prefix_dummy'
        @hosts_file = 'dummy_hosts'
      end

      it 'creates the correct content for an event' do
        log_line = network_manager.log_sut_event host, true
        pieces = log_line.split("\t")
        hypervisor_value = host['hypervisor'] ? host['hypervisor'] : ''
        platform_value = host['platform'] ? host['platform'] : ''
        expect( pieces[1] ).to be === '[+]'
        expect( pieces[2] ).to be === hypervisor_value
        expect( pieces[3] ).to be === platform_value
        expect( pieces[4] ).to be === host.log_prefix
      end

      it 'follows the create parameter correctly' do
        log_line = network_manager.log_sut_event host, true
        pieces = log_line.split("\t")
        expect( pieces[1] ).to be === '[+]'

        log_line = network_manager.log_sut_event host, false
        pieces = log_line.split("\t")
        expect( pieces[1] ).to be === '[-]'
      end

      it 'sends the log line to the provisioning logger' do
        nm = network_manager
        options[:logger_sut] = mock_provisioning_logger
        expect( mock_provisioning_logger ).to receive( :notify ).once
        nm.log_sut_event host, true
      end

      it 'throws an error if the provisioning logger hasn\'t been created yet' do
        nm = network_manager
        options.delete(:logger_sut)
        expect{ nm.log_sut_event(host, true) }.to raise_error(ArgumentError)
      end
    end

    it 'uses user defined log prefix if it is provided' do
      @log_prefix = 'dummy_log_prefix'
      @hosts_file = 'dummy_hosts'
      network_manager
      cur_prefix = options[:log_prefix]
      expect(cur_prefix).to be === @log_prefix
    end

    it 'uses host based log prefix, when there is not user defined log prefix' do
      @log_prefix = nil
      @hosts_file = 'dummy_hosts'
      network_manager
      cur_prefix = options[:log_prefix]
      expect(cur_prefix).to be === @hosts_file
    end

    it 'uses default log prefix, when there is no user defined and no host file' do
      @log_prefix = nil
      @hosts_file = nil
      network_manager
      cur_prefix = options[:log_prefix]
      expect(cur_prefix).to be === 'hello_default'
    end
  end
end
