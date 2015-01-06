# encoding: UTF-8
require 'spec_helper'

module Beaker
  describe NetworkManager do
    let( :mock_provisioning_logger ) {
      mock_provisioning_logger = Object.new
      allow( mock_provisioning_logger ).to receive( :notify )
      mock_provisioning_logger }
    let( :options ) { make_opts.merge({ 'logger' => double().as_null_object, :logger_provisioning => mock_provisioning_logger }) }
    let( :network_manager ) { NetworkManager.new(options, options[:logger]) }
    let( :hosts ) { make_hosts }
    let( :host ) { hosts[0] }

    describe '#log_provisioning' do

      it 'creates the correct content for an event' do
        log_line = network_manager.log_provisioning host, true
        pieces = log_line.split("\t")
        hypervisor_value = host['hypervisor'] ? host['hypervisor'] : ''
        platform_value = host['platform'] ? host['platform'] : ''
        expect( pieces[1] ).to be === '[+]'
        expect( pieces[2] ).to be === hypervisor_value
        expect( pieces[3] ).to be === platform_value
        expect( pieces[4] ).to be === host.name
      end

      it 'stores the log line in the options for summary use later' do
        provisioning_lines_before = options[:log_provisioning_facts] ? options[:log_provisioning_facts] : ''
        log_line = network_manager.log_provisioning host, true
        answer_lines = "#{provisioning_lines_before}#{log_line}\n"
        expect( options[:log_provisioning_facts] ).to be === answer_lines
      end

      it 'follows the create parameter correctly' do
        log_line = network_manager.log_provisioning host, true
        pieces = log_line.split("\t")
        expect( pieces[1] ).to be === '[+]'

        log_line = network_manager.log_provisioning host, false
        pieces = log_line.split("\t")
        expect( pieces[1] ).to be === '[-]'
      end

      it 'sends the log line to the provisioning logger' do
        nm = network_manager
        options[:logger_provisioning] = mock_provisioning_logger
        expect( mock_provisioning_logger ).to receive( :notify ).once
        nm.log_provisioning host, true
      end

      it 'throws an error if the provisioning logger hasn\'t been created yet' do
        nm = network_manager
        options.delete(:logger_provisioning)
        expect{ nm.log_provisioning(host, true) }.to raise_error(ArgumentError)
      end
    end
  end
end