require 'spec_helper'

module Beaker
  describe Answers do
    let( :basic_hosts ) { make_hosts( { 'pe_ver' => @ver } ) }
    let( :options )     { Beaker::Options::Presets.env_vars }
    let( :hosts )       { basic_hosts[0]['roles'] = ['master', 'database', 'dashboard']
                          basic_hosts[1]['platform'] = 'windows'
                          basic_hosts }
    let( :master_certname ) { 'master_certname' }

    it 'generates 3.2 answers for 3.3 hosts' do
      @ver = '3.3'
      Beaker::Answers::Version32.should_receive( :answers ).with( hosts, master_certname, {}).once
      subject.answers( @ver, hosts, master_certname, {} )
    end

    it 'generates 3.2 answers for 3.2 hosts' do
      @ver = '3.2'
      Beaker::Answers::Version32.should_receive( :answers ).with( hosts, master_certname, options ).once
      subject.answers( @ver, hosts, master_certname, options )
    end

    it 'generates 3.0 answers for 3.1 hosts' do
      @ver = '3.1'
      Beaker::Answers::Version30.should_receive( :answers ).with( hosts, master_certname, options ).once
      subject.answers( @ver, hosts, master_certname, options )
    end

    it 'generates 3.0 answers for 3.0 hosts' do
      @ver = '3.0'
      Beaker::Answers::Version30.should_receive( :answers ).with( hosts, master_certname, options ).once
      subject.answers( @ver, hosts, master_certname, options )
    end

    it 'generates 2.8 answers for 2.8 hosts' do
      @ver = '2.8'
      Beaker::Answers::Version28.should_receive( :answers ).with( hosts, master_certname, options ).once
      subject.answers( @ver, hosts, master_certname, options )
    end

    it 'generates 2.0 answers for 2.0 hosts' do
      @ver = '2.0'
      Beaker::Answers::Version20.should_receive( :answers ).with( hosts, master_certname, options ).once
      subject.answers( @ver, hosts, master_certname, options )
    end

    it 'raises an error for an unknown version' do
      @ver = 'x.x'
      expect{ subject.answers( @ver, hosts, master_certname, options ) }.to raise_error( NotImplementedError )
    end
  end

  module Answers
    describe Version32 do
      let( :options )     { Beaker::Options::Presets.env_vars }
      let( :basic_hosts ) { make_hosts( {'pe_ver' => @ver } ) }
      let( :hosts ) { basic_hosts[0]['roles'] = ['master', 'agent']
                      basic_hosts[1]['roles'] = ['dashboard', 'agent']
                      basic_hosts[2]['roles'] = ['database', 'agent']
                      basic_hosts }
      let( :master_certname ) { 'master_certname' }

      # The only difference between 3.2 and 3.0 is the addition of the
      # master certname to the dashboard answers
      it 'should add q_puppetmaster_certname to the dashboard answers' do
        @ver = '3.2'
        expect( subject.answers( hosts, master_certname, options )['vm2']).to include :q_puppetmaster_certname
      end

      it 'should add q_upgrade_with_unknown_disk_space to the dashboard on upgrade' do
        @ver = '3.2'
        expect( subject.answers( hosts, master_certname, options.merge( {:type => :upgrade} ) )['vm2']).to include :q_upgrade_with_unknown_disk_space
      end

      it 'should add answers to the host objects' do
        @ver = '3.2'
        answers = subject.answers( hosts, master_certname, options )
        hosts.each do |host|
          expect( host[:answers] ).to be === answers[host.name]
        end
      end
    end

    describe Version30 do
      let( :options )     { Beaker::Options::Presets.env_vars }
      let( :basic_hosts ) { make_hosts( { 'pe_ver' => @ver } ) }
      let( :hosts )       { basic_hosts[0]['roles'] = ['master', 'database', 'dashboard']
                            basic_hosts[1]['platform'] = 'windows'
                            basic_hosts }
      let( :master_certname ) { 'master_certname' }

      it 'uses simple answers for upgrade from 3.0.x to 3.0.x' do
        @ver = '3.0'
        expect( subject.answers( hosts, master_certname, options.merge({ :type => :upgrade }) )).to be === { "vm2"=>{ :q_install=>"y", :q_install_vendor_packages=>"y" }, "vm1"=>{ :q_install=>"y", :q_install_vendor_packages=>"y" }, "vm3"=>{ :q_install=>"y", :q_install_vendor_packages=>"y" } }
      end

      it 'sets correct answers for an agent' do
        expect( subject.answers( hosts, master_certname, options )['vm3'] ).to be === { :q_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_verify_packages=>"y", :q_puppet_symlinks_install=>"y", :q_puppetagent_certname=>hosts[2], :q_puppetagent_server=>master_certname, :q_puppetmaster_install=>"n", :q_all_in_one_install=>"n", :q_puppet_enterpriseconsole_install=>"n", :q_puppetdb_install=>"n", :q_database_install=>"n" }
      end

      it 'sets correct answers for a master' do
        @ver = '3.0'
        expect( subject.answers( hosts, master_certname, options )['vm1'] ).to be === { :q_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_verify_packages=>"y", :q_puppet_symlinks_install=>"y", :q_puppetagent_certname=>hosts[0], :q_puppetagent_server=>master_certname, :q_puppetmaster_install=>"y", :q_all_in_one_install=>"y", :q_puppet_enterpriseconsole_install=>"y", :q_puppetdb_install=>"y", :q_database_install=>"y", :q_puppetdb_hostname=>hosts[0], :q_puppetdb_port=>8081, :q_puppetmaster_dnsaltnames=>"master_certname,puppet,#{hosts[0][:ip]}", :q_puppetmaster_enterpriseconsole_hostname=>hosts[0], :q_puppetmaster_enterpriseconsole_port=>443, :q_puppetmaster_certname=>"master_certname", :q_puppetdb_database_name=>"pe-puppetdb", :q_puppetdb_database_user=>"mYpdBu3r", :q_puppetdb_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_auth_database_name=>"console_auth", :q_puppet_enterpriseconsole_auth_database_user=>"mYu7hu3r", :q_puppet_enterpriseconsole_auth_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_database_name=>"console", :q_puppet_enterpriseconsole_database_user=>"mYc0nS03u3r", :q_puppet_enterpriseconsole_database_password=>"'~!@\#$%^*-/ aZ'", :q_database_host=>hosts[0], :q_database_port=>5432, :q_pe_database=>"y", :q_puppet_enterpriseconsole_inventory_hostname=>hosts[0], :q_puppet_enterpriseconsole_inventory_certname=>hosts[0], :q_puppet_enterpriseconsole_inventory_dnsaltnames=>hosts[0], :q_puppet_enterpriseconsole_inventory_port=>8140, :q_puppet_enterpriseconsole_master_hostname=>hosts[0], :q_puppet_enterpriseconsole_auth_user_email=>"'admin@example.com'", :q_puppet_enterpriseconsole_auth_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_httpd_port=>443, :q_puppet_enterpriseconsole_smtp_host=>"'vm1'", :q_puppet_enterpriseconsole_smtp_use_tls=>"'n'", :q_puppet_enterpriseconsole_smtp_port=>"'25'", :q_database_root_password=>"'=ZYdjiP3jCwV5eo9s1MBd'", :q_database_root_user=>"pe-postgres" }
      end

      it 'generates nil answers for a windows host' do
        @ver = '3.0'
        expect( subject.answers( hosts, master_certname, options )['vm2'] ).to be === nil
      end

      it 'should add answers to the host objects' do
        @ver = '3.0'
        answers = subject.answers( hosts, master_certname, options )
        hosts.each do |host|
          expect( host[:answers] ).to be === answers[host.name]
        end
      end
    end

    describe Version28 do
      let( :options )     { Beaker::Options::Presets.env_vars }
      let( :basic_hosts ) { make_hosts( { 'pe_ver' => @ver } ) }
      let( :hosts )       { basic_hosts[0]['roles'] = ['master', 'database', 'dashboard']
                            basic_hosts[1]['platform'] = 'windows'
                            basic_hosts }
      let( :master_certname ) { 'master_certname' }

      it 'sets correct answers for an agent' do
        @ver = '2.8'
        expect( subject.answers( hosts, master_certname, options )['vm3'] ).to be === { :q_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_puppet_symlinks_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_certname=>hosts[2], :q_puppetagent_server=>hosts[0], :q_puppetmaster_install=>"n", :q_puppet_enterpriseconsole_install=>"n" }
      end

      it 'sets correct answers for a master' do
        @ver = '2.8'
        expect( subject.answers( hosts, master_certname, options )['vm1'] ).to be === { :q_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_puppet_symlinks_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_certname=>hosts[0], :q_puppetagent_server=>hosts[0], :q_puppetmaster_install=>"y", :q_puppet_enterpriseconsole_install=>"y", :q_puppetmaster_certname=>"master_certname", :q_puppetmaster_dnsaltnames=>"master_certname,puppet,#{hosts[0][:ip]}", :q_puppetmaster_enterpriseconsole_hostname=>hosts[0], :q_puppetmaster_enterpriseconsole_port=>443, :q_puppetmaster_forward_facts=>"y", :q_puppet_enterpriseconsole_database_install=>"y", :q_puppet_enterpriseconsole_auth_database_name=>"console_auth", :q_puppet_enterpriseconsole_auth_database_user=>"mYu7hu3r", :q_puppet_enterpriseconsole_auth_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_database_name=>"console", :q_puppet_enterpriseconsole_database_user=>"mYc0nS03u3r", :q_puppet_enterpriseconsole_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_inventory_hostname=>hosts[0], :q_puppet_enterpriseconsole_inventory_certname=>hosts[0], :q_puppet_enterpriseconsole_inventory_dnsaltnames=>hosts[0], :q_puppet_enterpriseconsole_inventory_port=>8140, :q_puppet_enterpriseconsole_master_hostname=>hosts[0], :q_puppet_enterpriseconsole_auth_user_email=>"'admin@example.com'", :q_puppet_enterpriseconsole_auth_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_httpd_port=>443, :q_puppet_enterpriseconsole_smtp_host=>"'vm1'", :q_puppet_enterpriseconsole_smtp_use_tls=>"'n'", :q_puppet_enterpriseconsole_smtp_port=>"'25'", :q_puppet_enterpriseconsole_auth_user=>"'admin@example.com'" }
      end

      it 'generates nil answers for a windows host' do
        @ver = '2.8'
        expect( subject.answers( hosts, master_certname, options )['vm2'] ).to be === nil
      end

      it 'should add answers to the host objects' do
        @ver = '2.8'
        answers = subject.answers( hosts, master_certname, options )
        hosts.each do |host|
          expect( host[:answers] ).to be === answers[host.name]
        end
      end

    end
    describe Version20 do
      let( :options )     { Beaker::Options::Presets.env_vars }
      let( :basic_hosts ) { make_hosts( { 'pe_ver' => @ver } ) }
      let( :hosts )       { basic_hosts[0]['roles'] = ['master', 'database', 'dashboard']
                            basic_hosts[1]['platform'] = 'windows'
                            basic_hosts }
      let( :master_certname ) { 'master_certname' }

      it 'sets correct answers for an agent' do
        @ver = '2.0'
        expect( subject.answers( hosts, master_certname, options )['vm3'] ).to be === { :q_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_puppet_symlinks_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_certname=>hosts[2], :q_puppetagent_server=>hosts[0], :q_puppetmaster_install=>"n", :q_puppet_enterpriseconsole_install=>"n" }
      end

      it 'sets correct answers for a master' do
        @ver = '2.0'
        expect( subject.answers( hosts, master_certname, options )['vm1'] ).to be === { :q_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_puppet_symlinks_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_certname=>hosts[0], :q_puppetagent_server=>hosts[0], :q_puppetmaster_install=>"y", :q_puppet_enterpriseconsole_install=>"y", :q_puppetmaster_certname=>"master_certname", :q_puppetmaster_dnsaltnames=>"master_certname,puppet,#{hosts[0][:ip]}", :q_puppetmaster_enterpriseconsole_hostname=>hosts[0], :q_puppetmaster_enterpriseconsole_port=>443, :q_puppetmaster_forward_facts=>"y", :q_puppet_enterpriseconsole_database_install=>"y", :q_puppet_enterpriseconsole_auth_database_name=>"console_auth", :q_puppet_enterpriseconsole_auth_database_user=>"mYu7hu3r", :q_puppet_enterpriseconsole_auth_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_database_name=>"console", :q_puppet_enterpriseconsole_database_user=>"mYc0nS03u3r", :q_puppet_enterpriseconsole_database_root_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_inventory_hostname=>hosts[0], :q_puppet_enterpriseconsole_inventory_certname=>hosts[0], :q_puppet_enterpriseconsole_inventory_dnsaltnames=>hosts[0], :q_puppet_enterpriseconsole_inventory_port=>8140, :q_puppet_enterpriseconsole_master_hostname=>hosts[0], :q_puppet_enterpriseconsole_auth_user_email=>"'admin@example.com'", :q_puppet_enterpriseconsole_auth_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_httpd_port=>443, :q_puppet_enterpriseconsole_smtp_host=>"'vm1'", :q_puppet_enterpriseconsole_smtp_use_tls=>"'n'", :q_puppet_enterpriseconsole_smtp_port=>"'25'", :q_puppet_enterpriseconsole_auth_user=>"'admin@example.com'" }
      end

      it 'generates nil answers for a windows host' do
        @ver = '2.0'
        expect( subject.answers( hosts, master_certname, options )['vm2'] ).to be === nil
      end

      it 'should add answers to the host objects' do
        @ver = '2.0'
        answers = subject.answers( hosts, master_certname, options )
        hosts.each do |host|
          expect( host[:answers] ).to be === answers[host.name]
        end
      end

    end

  end
end
