require 'spec_helper'

module Beaker
  describe CLI do
    let(:cli)      { Beaker::CLI.new }

    context 'execute!' do
      before :each do
       stub_const("Beaker::Logger", double().as_null_object )
        File.open("sample.cfg", "w+") do |file|
          file.write("HOSTS:\n")
          file.write("  myhost:\n")
          file.write("    roles:\n")
          file.write("      - master\n")
          file.write("    platform: ubuntu-x-x\n")
          file.write("CONFIG:\n")
        end
        allow( cli ).to receive(:setup).and_return(true)
        allow( cli ).to receive(:validate).and_return(true)
        allow( cli ).to receive(:provision).and_return(true)
      end

      describe "test fail mode" do
        it 'continues testing after failed test if using slow fail_mode' do
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests).and_throw("bad test")
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'slow'
          cli.instance_variable_set(:@options, options)

          expect( cli ).to receive(:run_suite).exactly( 3 ).times
          expect{ cli.execute! }.to raise_error

        end

        it 'stops testing after failed test if using fast fail_mode' do
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests).and_throw("bad test")
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          cli.instance_variable_set(:@options, options)

          expect( cli ).to receive(:run_suite).exactly( 2 ).times
          expect{ cli.execute! }.to raise_error

        end
      end

      describe "SUT preserve mode" do
        it 'cleans up SUTs post testing if tests fail and preserve_hosts = never' do
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests).and_throw("bad test")
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'never'
          cli.instance_variable_set(:@options, options)

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).to receive(:cleanup).once

          expect{ cli.execute! }.to raise_error

        end

        it 'cleans up SUTs post testing if no tests fail and preserve_hosts = never' do
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests).and_return(true)
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'never'
          cli.instance_variable_set(:@options, options)

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).to receive(:cleanup).once

          expect{ cli.execute! }.to_not raise_error

        end


        it 'preserves SUTs post testing if no tests fail and preserve_hosts = always' do
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests).and_return(true)
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'always'
          cli.instance_variable_set(:@options, options)

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).to receive(:cleanup).never

          expect{ cli.execute! }.to_not raise_error

        end

        it 'preserves SUTs post testing if no tests fail and preserve_hosts = always' do
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests).and_throw("bad test")
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'always'
          cli.instance_variable_set(:@options, options)

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).to receive(:cleanup).never

          expect{ cli.execute! }.to raise_error
        end

        it 'cleans up SUTs post testing if no tests fail and preserve_hosts = onfail' do
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests).and_return(true)
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'onfail'
          cli.instance_variable_set(:@options, options)

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).to receive(:cleanup).once

          expect{ cli.execute! }.to_not raise_error

        end

        it 'preserves SUTs post testing if tests fail and preserve_hosts = onfail' do
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests).and_throw("bad test")
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'onfail'
          cli.instance_variable_set(:@options, options)

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).to receive(:cleanup).never

          expect{ cli.execute! }.to raise_error

        end

        it 'cleans up SUTs post testing if tests fail and preserve_hosts = onpass' do
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests).and_throw("bad test")
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'onpass'
          cli.instance_variable_set(:@options, options)

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).to receive(:cleanup).once

          expect{ cli.execute! }.to raise_error

        end

        it 'preserves SUTs post testing if no tests fail and preserve_hosts = onpass' do
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests).and_return(true)
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'onpass'
          cli.instance_variable_set(:@options, options)

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).to receive(:cleanup).never

          expect{ cli.execute! }.to_not raise_error
        end
      end
    end
  end
end
