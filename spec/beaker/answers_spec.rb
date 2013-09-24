require 'spec_helper'

module Beaker
  describe Answers do
    let(:options) {Beaker::Options::OptionsHash.new.merge({'HOSTS' => {
                   'master' => {'platform' => 'linux', 'pe_ver' => @ver, 'roles' => ['master', 'database', 'dashboard']},
                   'agent1' => {'platform' => 'windows', 'pe_ver' => @ver, 'roles' => ['agent']},
                   'agent2' => {'platform' => 'linux', 'pe_ver' => @ver, 'roles' => ['agent']},
    }})}
    let(:hosts) {
               [Beaker::Host.create('agent1', options),
               Beaker::Host.create('master', options),
               Beaker::Host.create('agent2', options),]
    }
    let(:master_certname) {'master_certname'}
    it 'generates 3.0 answers for 3.1 hosts' do
      @ver = '3.1'
      Beaker::Answers::Version30.should_receive( :answers ).with(hosts, master_certname, {}).exactly(1).times
      subject.answers(@ver, hosts, master_certname, {})
    end
    it 'generates 3.0 answers for 3.0 hosts' do
      @ver = '3.0'
      Beaker::Answers::Version30.should_receive( :answers ).with(hosts, master_certname, {}).exactly(1).times
      subject.answers(@ver, hosts, master_certname, {})
    end
    it 'generates 2.8 answers for 2.8 hosts' do
      @ver = '2.8'
      Beaker::Answers::Version28.should_receive( :answers ).with(hosts, master_certname, {}).exactly(1).times
      subject.answers(@ver, hosts, master_certname, {})
    end
    it 'generates 2.0 answers for 2.0 hosts' do
      @ver = '2.0'
      Beaker::Answers::Version20.should_receive( :answers ).with(hosts, master_certname, {}).exactly(1).times
      subject.answers(@ver, hosts, master_certname, {})
    end
    it 'raises an error for an unknown version' do
      @ver = 'x.x'
      expect{subject.answers(@ver, hosts, master_certname, {})}.to raise_error(NotImplementedError)
    end
  end
  module Answers
    describe Version30 do
      let(:options) {Beaker::Options::OptionsHash.new.merge({'HOSTS' => {
                     'master' => {'platform' => 'linux', :pe_ver => @ver, 'roles' => ['master', 'database', 'dashboard']},
                     'agent1' => {'platform' => 'windows', :pe_ver => @ver, 'roles' => ['agent']},
                     'agent2' => {'platform' => 'linux', :pe_ver => @ver, 'roles' => ['agent']},
      }})}
      let(:hosts) {
                 [Beaker::Host.create('agent1', options),
                 Beaker::Host.create('master', options),
                 Beaker::Host.create('agent2', options),]
      }
      let(:master_certname) {'master_certname'}
      it 'uses simple answers for upgrade from 3.0.x to 3.0.x' do
        @ver = '3.0'
        expect(subject.answers(hosts, master_certname, {:type => :upgrade})).to be === {"agent1"=>{:q_install=>"y", :q_install_vendor_packages=>"y"}, "master"=>{:q_install=>"y", :q_install_vendor_packages=>"y"}, "agent2"=>{:q_install=>"y", :q_install_vendor_packages=>"y"}}
      end
      it 'sets correct answers for an agent' do
        expect(subject.answers(hosts, master_certname,{})['agent2']).to be === {:q_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_verify_packages=>"y", :q_puppet_symlinks_install=>"y", :q_puppetagent_certname=>hosts[2], :q_puppetagent_server=>hosts[1], :q_puppetmaster_install=>"n", :q_all_in_one_install=>"n", :q_puppet_enterpriseconsole_install=>"n", :q_puppetdb_install=>"n", :q_database_install=>"n"}
      end
      it 'sets correct answers for a master' do
        expect(subject.answers(hosts, master_certname, {})['master']).to be === {:q_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_verify_packages=>"y", :q_puppet_symlinks_install=>"y", :q_puppetagent_certname=>hosts[1], :q_puppetagent_server=>hosts[1], :q_puppetmaster_install=>"y", :q_all_in_one_install=>"y", :q_puppet_enterpriseconsole_install=>"y", :q_puppetdb_install=>"y", :q_database_install=>"y", :q_puppetdb_hostname=>hosts[1], :q_puppetdb_port=>8081, :q_puppetmaster_dnsaltnames=>"master_certname,puppet", :q_puppetmaster_enterpriseconsole_hostname=>hosts[1], :q_puppetmaster_enterpriseconsole_port=>443, :q_puppetmaster_certname=>"master_certname", :q_puppetdb_database_name=>"pe-puppetdb", :q_puppetdb_database_user=>"mYpdBu3r", :q_puppetdb_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_auth_database_name=>"console_auth", :q_puppet_enterpriseconsole_auth_database_user=>"mYu7hu3r", :q_puppet_enterpriseconsole_auth_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_database_name=>"console", :q_puppet_enterpriseconsole_database_user=>"mYc0nS03u3r", :q_puppet_enterpriseconsole_database_password=>"'~!@\#$%^*-/ aZ'", :q_database_host=>hosts[1], :q_database_port=>5432, :q_pe_database=>"y", :q_puppet_enterpriseconsole_inventory_hostname=>hosts[1], :q_puppet_enterpriseconsole_inventory_certname=>hosts[1], :q_puppet_enterpriseconsole_inventory_dnsaltnames=>hosts[1], :q_puppet_enterpriseconsole_inventory_port=>8140, :q_puppet_enterpriseconsole_master_hostname=>hosts[1], :q_puppet_enterpriseconsole_auth_user_email=>"'admin@example.com'", :q_puppet_enterpriseconsole_auth_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_httpd_port=>443, :q_puppet_enterpriseconsole_smtp_host=>"'master'", :q_puppet_enterpriseconsole_smtp_use_tls=>"'n'", :q_puppet_enterpriseconsole_smtp_port=>"'25'", :q_database_root_password=>"'=ZYdjiP3jCwV5eo9s1MBd'", :q_database_root_user=>"pe-postgres"}
      end
      it 'generates nil answers for a windows host' do
        expect(subject.answers(hosts, master_certname, {})['agent1']).to be === nil
      end
    end

    describe Version28 do
      let(:options) {Beaker::Options::OptionsHash.new.merge({'HOSTS' => {
                     'master' => {'platform' => 'linux', :pe_ver => '2.8', 'roles' => ['master', 'database', 'dashboard']},
                     'agent1' => {'platform' => 'windows', :pe_ver => '2.8', 'roles' => ['agent']},
                     'agent2' => {'platform' => 'linux', :pe_ver => '2.8', 'roles' => ['agent']},
      }})}
      let(:hosts) {
                 [Beaker::Host.create('agent1', options),
                 Beaker::Host.create('master', options),
                 Beaker::Host.create('agent2', options),]
      }
      let(:master_certname) {'master_certname'}
      it 'sets correct answers for an agent' do
        expect(subject.answers(hosts, master_certname,{})['agent2']).to be === {:q_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_puppet_symlinks_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_certname=>hosts[2], :q_puppetagent_server=>hosts[1], :q_puppetmaster_install=>"n", :q_puppet_enterpriseconsole_install=>"n"}
      end
      it 'sets correct answers for a master' do
        expect(subject.answers(hosts, master_certname, {})['master']).to be === {:q_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_puppet_symlinks_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_certname=>hosts[1], :q_puppetagent_server=>hosts[1], :q_puppetmaster_install=>"y", :q_puppet_enterpriseconsole_install=>"y", :q_puppetmaster_certname=>"master_certname", :q_puppetmaster_dnsaltnames=>"master_certname,puppet", :q_puppetmaster_enterpriseconsole_hostname=>hosts[1], :q_puppetmaster_enterpriseconsole_port=>443, :q_puppetmaster_forward_facts=>"y", :q_puppet_enterpriseconsole_database_install=>"y", :q_puppet_enterpriseconsole_auth_database_name=>"console_auth", :q_puppet_enterpriseconsole_auth_database_user=>"mYu7hu3r", :q_puppet_enterpriseconsole_auth_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_database_name=>"console", :q_puppet_enterpriseconsole_database_user=>"mYc0nS03u3r", :q_puppet_enterpriseconsole_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_inventory_hostname=>hosts[1], :q_puppet_enterpriseconsole_inventory_certname=>hosts[1], :q_puppet_enterpriseconsole_inventory_dnsaltnames=>hosts[1], :q_puppet_enterpriseconsole_inventory_port=>8140, :q_puppet_enterpriseconsole_master_hostname=>hosts[1], :q_puppet_enterpriseconsole_auth_user_email=>"'admin@example.com'", :q_puppet_enterpriseconsole_auth_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_httpd_port=>443, :q_puppet_enterpriseconsole_smtp_host=>"'master'", :q_puppet_enterpriseconsole_smtp_use_tls=>"'n'", :q_puppet_enterpriseconsole_smtp_port=>"'25'", :q_puppet_enterpriseconsole_auth_user=>"'admin@example.com'"}
      end
      it 'generates nil answers for a windows host' do
        expect(subject.answers(hosts, master_certname, {})['agent1']).to be === nil
      end


    end
    describe Version20 do
      let(:options) {Beaker::Options::OptionsHash.new.merge({'HOSTS' => {
                     'master' => {'platform' => 'linux', :pe_ver => '2.8', 'roles' => ['master', 'database', 'dashboard']},
                     'agent1' => {'platform' => 'windows', :pe_ver => '2.8', 'roles' => ['agent']},
                     'agent2' => {'platform' => 'linux', :pe_ver => '2.8', 'roles' => ['agent']},
      }})}
      let(:hosts) {
                 [Beaker::Host.create('agent1', options),
                 Beaker::Host.create('master', options),
                 Beaker::Host.create('agent2', options),]
      }
      let(:master_certname) {'master_certname'}
      it 'sets correct answers for an agent' do
        expect(subject.answers(hosts, master_certname,{})['agent2']).to be === {:q_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_puppet_symlinks_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_certname=>hosts[2], :q_puppetagent_server=>hosts[1], :q_puppetmaster_install=>"n", :q_puppet_enterpriseconsole_install=>"n"}
      end
      it 'sets correct answers for a master' do
        expect(subject.answers(hosts, master_certname, {})['master']).to be === {:q_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_puppet_symlinks_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_certname=>hosts[1], :q_puppetagent_server=>hosts[1], :q_puppetmaster_install=>"y", :q_puppet_enterpriseconsole_install=>"y", :q_puppetmaster_certname=>"master_certname", :q_puppetmaster_dnsaltnames=>"master_certname,puppet", :q_puppetmaster_enterpriseconsole_hostname=>hosts[1], :q_puppetmaster_enterpriseconsole_port=>443, :q_puppetmaster_forward_facts=>"y", :q_puppet_enterpriseconsole_database_install=>"y", :q_puppet_enterpriseconsole_auth_database_name=>"console_auth", :q_puppet_enterpriseconsole_auth_database_user=>"mYu7hu3r", :q_puppet_enterpriseconsole_auth_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_database_name=>"console", :q_puppet_enterpriseconsole_database_user=>"mYc0nS03u3r", :q_puppet_enterpriseconsole_database_root_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_inventory_hostname=>hosts[1], :q_puppet_enterpriseconsole_inventory_certname=>hosts[1], :q_puppet_enterpriseconsole_inventory_dnsaltnames=>hosts[1], :q_puppet_enterpriseconsole_inventory_port=>8140, :q_puppet_enterpriseconsole_master_hostname=>hosts[1], :q_puppet_enterpriseconsole_auth_user_email=>"'admin@example.com'", :q_puppet_enterpriseconsole_auth_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_httpd_port=>443, :q_puppet_enterpriseconsole_smtp_host=>"'master'", :q_puppet_enterpriseconsole_smtp_use_tls=>"'n'", :q_puppet_enterpriseconsole_smtp_port=>"'25'", :q_puppet_enterpriseconsole_auth_user=>"'admin@example.com'"}
      end
      it 'generates nil answers for a windows host' do
        expect(subject.answers(hosts, master_certname, {})['agent1']).to be === nil
      end


    end

  end
end
