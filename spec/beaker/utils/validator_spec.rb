require 'spec_helper'

module Beaker
  module Utils
    describe Validator do
      let( :validator )      { Beaker::Utils::Validator }
      let( :pkgs )           { Beaker::Utils::Validator::PACKAGES }
      let( :unix_only_pkgs ) { Beaker::Utils::Validator::UNIX_PACKAGES }
      let( :sles_only_pkgs ) { Beaker::Utils::Validator::SLES_PACKAGES }
      let( :platform )       { @platform || 'unix' }
      let( :hosts )          { hosts = make_hosts( { :platform => platform } )
                               hosts[0][:roles] = ['agent']
                               hosts[1][:roles] = ['master', 'dashboard', 'agent', 'database']
                               hosts[2][:roles] = ['agent']
                               hosts }

      context "can validate the SUTs" do

        it "can validate unix hosts" do

          hosts.each do |host|
            pkgs.each do |pkg|
              host.should_receive( :check_for_package ).with( pkg ).once.and_return( false )
              host.should_receive( :install_package ).with( pkg ).once
            end
            unix_only_pkgs.each do |pkg|
              host.should_receive( :check_for_package ).with( pkg ).once.and_return( false )
              host.should_receive( :install_package ).with( pkg ).once
            end
            sles_only_pkgs.each do |pkg|
              host.should_receive( :check_for_package).with( pkg ).never
              host.should_receive( :install_package ).with( pkg ).never
            end
            
          end

          validator.validate(hosts, logger)

        end

        it "can validate windows hosts" do
          @platform = 'windows'

          hosts.each do |host|
            pkgs.each do |pkg|
              host.should_receive( :check_for_package ).with( pkg ).once.and_return( false )
              host.should_receive( :install_package ).with( pkg ).once
            end
            unix_only_pkgs.each do |pkg|
              host.should_receive( :check_for_package).with( pkg ).never
              host.should_receive( :install_package ).with( pkg ).never
            end
            sles_only_pkgs.each do |pkg|
              host.should_receive( :check_for_package).with( pkg ).never
              host.should_receive( :install_package ).with( pkg ).never
            end

          end

          validator.validate(hosts, logger)

        end

        it "can validate SLES hosts" do
          @platform = 'sles-13.1-x64'

          hosts.each do |host|
            pkgs.each do |pkg|
              host.should_receive( :check_for_package ).with( pkg ).once.and_return( false )
              host.should_receive( :install_package ).with( pkg ).once
            end
            unix_only_pkgs.each do |pkg|
              host.should_receive( :check_for_package).with( pkg ).never
              host.should_receive( :install_package ).with( pkg ).never
            end
            sles_only_pkgs.each do |pkg|
              host.should_receive( :check_for_package).with( pkg ).once.and_return( false )
              host.should_receive( :install_package ).with( pkg ).once
            end

          end

          validator.validate(hosts, logger)

        end
      end


    end
  end
end
