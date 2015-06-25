require 'spec_helper'

module Beaker
  describe Answers do
    let( :basic_hosts ) { make_hosts( { 'pe_ver' => @ver } ) }
    let( :options )     { Beaker::Options::Presets.new.presets }
    let( :hosts )       { basic_hosts[0]['roles'] = ['master', 'database', 'dashboard']
                          basic_hosts[1]['platform'] = 'windows'
                          basic_hosts }
    let( :answers )     { Beaker::Answers.create(@ver, hosts, options) }

    it 'generates 3.4 answers for 4.0 hosts' do
      @ver = '4.0'
      expect( answers ).to be_a_kind_of Version34
    end

    it 'generates 4.0 answers for 3.99 hosts' do
      @ver = '3.99'
      expect( answers ).to be_a_kind_of Version40
    end

    it 'generates 3.8 answers for 3.8 hosts' do
      @ver = '3.8'
      expect( answers ).to be_a_kind_of Version38
    end

    it 'generates 3.4 answers for 3.4 hosts' do
      @ver = '3.4'
      expect( answers ).to be_a_kind_of Version34
    end

    it 'generates 3.2 answers for 3.3 hosts' do
      @ver = '3.3'
      expect( answers ).to be_a_kind_of Version32
    end

    it 'generates 3.2 answers for 3.2 hosts' do
      @ver = '3.2'
      expect( answers ).to be_a_kind_of Version32
    end

    it 'generates 3.0 answers for 3.1 hosts' do
      @ver = '3.1'
      expect( answers ).to be_a_kind_of Version30
    end

    it 'generates 3.0 answers for 3.0 hosts' do
      @ver = '3.0'
      expect( answers ).to be_a_kind_of Version30
    end

    it 'generates 2.8 answers for 2.8 hosts' do
      @ver = '2.8'
      expect( answers ).to be_a_kind_of Version28
    end

    it 'generates 2.0 answers for 2.0 hosts' do
      @ver = '2.0'
      expect( answers ).to be_a_kind_of Version20
    end

    it 'raises an error for an unknown version' do
      @ver = 'x.x'
      expect{ answers }.to raise_error( NotImplementedError )
    end
  end

  describe "Masterless Setup" do
    let( :ver ) { @ver || '3.0' }
    let( :options )     { options = Beaker::Options::Presets.new.presets
                          options[:masterless] = true
                          options }
    let( :hosts ) { make_hosts({}, 1) }
    let( :host ) { hosts[0] }
    let( :answers ) { Beaker::Answers.create(ver, hosts, options) }
    let( :host_answers ) { answers.answers[host.name] }


    it 'adds the correct answers' do
      expect( host_answers[:q_puppetagent_server] ).to be === host_answers[:q_puppetagent_certname]
      expect( host_answers[:q_continue_or_reenter_master_hostname]).to be === 'c'
    end

    it 'skips the correct answers' do
      expect( host_answers[:q_puppetmaster_install]).to be === 'n'
      expect( host_answers[:q_puppet_enterpriseconsole_install] ).to be === 'n'
      expect( host_answers[:q_puppetdb_install] ).to be === 'n'
    end

    it '3.0: never calls #only_host_with_role in #generate_answers' do
      expect( answers.generate_answers ).to_not receive( :only_host_with_role )
    end

    it '3.2: never calls #only_host_with_role in #generate_answers' do
      @ver = '3.2'
      expect( answers.generate_answers ).to_not receive( :only_host_with_role )
    end

    it '3.4: never calls #only_host_with_role in #generate_answers' do
      @ver = '3.4'
      expect( answers.generate_answers ).to_not receive( :only_host_with_role )
    end

  end

  describe Version34 do
    let( :options )     { Beaker::Options::Presets.new.presets }
    let( :basic_hosts ) { make_hosts( {'pe_ver' => @ver } ) }
    let( :hosts ) { basic_hosts[0]['roles'] = ['master', 'agent']
                    basic_hosts[0][:custom_answers] = { :q_custom => 'LOOKYHERE' }
                    basic_hosts[1]['roles'] = ['dashboard', 'agent']
                    basic_hosts[2]['roles'] = ['database', 'agent']
                    basic_hosts }
    let( :answers )     { Beaker::Answers.create(@ver, hosts, options) }

    before :each do
      @ver = '3.4'
      @answers = answers.answers
    end

    it 'should add console services answers to dashboard answers' do
      @ver = '3.4'
      answers = @answers
      expect( @answers['vm2'] ).to include :q_classifier_database_user => 'DFGhjlkj'
      expect( @answers['vm2'] ).to include :q_classifier_database_name => 'pe-classifier'
      expect( @answers['vm2'] ).to include :q_classifier_database_password => "'~!@\#$%^*-/ aZ'"
      expect( @answers['vm2'] ).to include :q_activity_database_user => 'adsfglkj'
      expect( @answers['vm2'] ).to include :q_activity_database_name => 'pe-activity'
      expect( @answers['vm2'] ).to include :q_activity_database_password => "'~!@\#$%^*-/ aZ'"
      expect( @answers['vm2'] ).to include :q_rbac_database_user => 'RbhNBklm'
      expect( @answers['vm2'] ).to include :q_rbac_database_name => 'pe-rbac'
      expect( @answers['vm2'] ).to include :q_rbac_database_password => "'~!@\#$%^*-/ aZ'"
    end

    it 'should add console services answers to database answers' do
      @ver = '3.4'
      answers = @answers
      expect( @answers['vm3'] ).to include :q_classifier_database_user => 'DFGhjlkj'
      expect( @answers['vm3'] ).to include :q_classifier_database_name => 'pe-classifier'
      expect( @answers['vm3'] ).to include :q_classifier_database_password => "'~!@\#$%^*-/ aZ'"
      expect( @answers['vm3'] ).to include :q_activity_database_user => 'adsfglkj'
      expect( @answers['vm3'] ).to include :q_activity_database_name => 'pe-activity'
      expect( @answers['vm3'] ).to include :q_activity_database_password => "'~!@\#$%^*-/ aZ'"
      expect( @answers['vm3'] ).to include :q_rbac_database_user => 'RbhNBklm'
      expect( @answers['vm3'] ).to include :q_rbac_database_name => 'pe-rbac'
      expect( @answers['vm3'] ).to include :q_rbac_database_password => "'~!@\#$%^*-/ aZ'"
    end

    it 'should add answers to the host objects' do
      @ver = '3.4'
      answers = @answers
      hosts.each do |host|
        expect( host[:answers] ).to be === answers[host.name]
      end
    end

    it 'should add answers to the host objects' do
      hosts.each do |host|
        expect( host[:answers] ).to be === @answers[host.name]
      end
    end

    it 'appends custom answers to generated answers' do
      expect( hosts[0][:custom_answers] ).to be == { :q_custom => 'LOOKYHERE' }
      expect( @answers['vm1'] ).to include :q_custom
      expect( hosts[0][:answers] ).to include :q_custom
    end

  end

  describe Version38 do
    let( :options )     { Beaker::Options::Presets.new.presets }
    let( :basic_hosts ) { make_hosts( {'pe_ver' => @ver } ) }
    let( :hosts ) { basic_hosts[0]['roles'] = ['master', 'agent']
                    basic_hosts[1]['roles'] = ['dashboard', 'database', 'agent']
                    basic_hosts[2]['roles'] = ['agent']
                    basic_hosts[2]['platform'] = 'windows2008r2'
                    basic_hosts }
    let( :answers )     { Beaker::Answers.create(@ver, hosts, options) }
    let( :upgrade_answers )     { Beaker::Answers.create(@ver, hosts, options.merge( {:type => :upgrade}) ) }

    before :each do
      @ver = '3.8'
      @answers = answers.answers
    end

    it 'should add q_pe_check_for_updates to master' do
      expect( @answers['vm1'][:q_pe_check_for_updates] ).to be === 'n'
    end

    it 'should add q_pe_check_for_updates to dashboard' do
      expect( @answers['vm2'][:q_pe_check_for_updates] ).to be === 'n'
    end

    it 'adds :q_enable_future_parser to all hosts, default to "n"' do
      hosts.each do |host|
        expect( basic_hosts[0][:answers][:q_enable_future_parser] ).to be == 'n'
        expect( basic_hosts[1][:answers][:q_enable_future_parser] ).to be == 'n'
      end
    end

    it 'adds :q_exit_for_nc_migrate to all hosts, default to "n"' do
      expect( basic_hosts[0][:answers][:q_exit_for_nc_migrate] ).to be == 'n'
      expect( basic_hosts[1][:answers][:q_exit_for_nc_migrate] ).to be == 'n'
    end

    it 'should add answers to the host objects' do
      hosts.each do |host|
        expect( host[:answers] ).to be === @answers[host.name]
      end
    end
  end

  describe Version40 do
    let( :options )     { Beaker::Options::Presets.new.presets }
    let( :basic_hosts ) { make_hosts( {'pe_ver' => @ver } ) }
    let( :hosts ) { basic_hosts[0]['roles'] = ['master', 'agent']
                    basic_hosts[1]['roles'] = ['dashboard', 'agent']
                    basic_hosts[2]['roles'] = ['database', 'agent']
                    basic_hosts }
    let( :answers )     { Beaker::Answers.create(@ver, hosts, options) }
    let( :upgrade_answers )     { Beaker::Answers.create(@ver, hosts, options.merge( {:type => :upgrade}) ) }

    before :each do
      @ver = '3.99'
      @answers = answers.answers
    end

    it 'should not have q_puppet_cloud_install key' do
      hosts.each do |host|
        expect( host[:answers] ).to_not include :q_puppet_cloud_install
      end
    end

    it 'should add q_pe_check_for_updates to master' do
      expect( @answers['vm1'][:q_pe_check_for_updates] ).to be === 'n'
    end

    it 'should add q_pe_check_for_updates to dashboard' do
      expect( @answers['vm2'][:q_pe_check_for_updates] ).to be === 'n'
    end

    it 'should not add q_pe_check_for_updates to agent/database' do
      expect( @answers['vm3']).to_not include :q_pe_check_for_updates
    end

# re-enable these tests once these keys are eliminated
#
#    it 'should not have q_puppet_enterpriseconsole_database_name key' do
#      hosts.each do |host|
#        expect( host[:answers] ).to_not include :q_puppet_enterpriseconsole_database_name
#      end
#    end
#
#    it 'should not have q_puppet_enterpriseconsole_database_password key' do
#      hosts.each do |host|
#        expect( host[:answers] ).to_not include :q_puppet_enterpriseconsole_database_password
#      end
#    end
#
#    it 'should not have q_puppet_enterpriseconsole_database_user key' do
#      hosts.each do |host|
#        expect( host[:answers] ).to_not include :q_puppet_enterpriseconsole_database_user
#      end
#    end

    it ':q_update_server_host should default to the master' do
      hosts.each do |host|
        expect( host[:answers][:q_update_server_host] ).to be == hosts[0]
      end
    end

    it 'only the master should have :q_install_update_server' do
      hosts.each do |host|
        if host[:roles].include? 'master'
          expect( host[:answers][:q_install_update_server] ).to be == 'y'
        else
          expect( host[:answers] ).to_not include :q_install_update_server
        end
      end
    end

    it 'should add answers to the host objects' do
      hosts.each do |host|
        expect( host[:answers] ).to be === @answers[host.name]
      end
    end
  end

  describe Version32 do
    let( :options )     { Beaker::Options::Presets.new.presets }
    let( :basic_hosts ) { make_hosts( {'pe_ver' => @ver } ) }
    let( :hosts ) { basic_hosts[0]['roles'] = ['master', 'agent']
                    basic_hosts[1]['roles'] = ['dashboard', 'agent']
                    basic_hosts[2]['roles'] = ['database', 'agent']
                    basic_hosts }
    let( :answers )     { Beaker::Answers.create(@ver, hosts, options) }
    let( :upgrade_answers )     { Beaker::Answers.create(@ver, hosts, options.merge( {:type => :upgrade}) ) }

    before :each do
      @ver = '3.2'
      @answers = answers.answers
    end

    it 'should add q_pe_check_for_updates to master' do
      expect( @answers['vm1'][:q_pe_check_for_updates] ).to be === 'n'
    end

    it 'should add q_pe_check_for_updates to dashboard' do
      expect( @answers['vm2'][:q_pe_check_for_updates] ).to be === 'n'
    end

    it 'should not add q_pe_check_for_updates to agent/database' do
      expect( @answers['vm3']).to_not include :q_pe_check_for_updates
    end

    # The only difference between 3.2 and 3.0 is the addition of the
    # master certname to the dashboard answers
    it 'should add q_puppetmaster_certname to the dashboard answers' do
      expect( @answers['vm2']).to include :q_puppetmaster_certname
    end

    it 'should add q_upgrade_with_unknown_disk_space to the dashboard on upgrade' do
      @upgrade_answers = upgrade_answers.answers
      expect( @upgrade_answers['vm2']).to include :q_upgrade_with_unknown_disk_space
    end

    it 'should add answers to the host objects' do
      hosts.each do |host|
        expect( host[:answers] ).to be === @answers[host.name]
      end
    end
  end

  describe Version30 do
    let( :options )     { Beaker::Options::Presets.new.presets }
    let( :basic_hosts ) { make_hosts( { 'pe_ver' => @ver } ) }
    let( :hosts )       { basic_hosts[0]['roles'] = ['master', 'database', 'dashboard']
                          basic_hosts[1]['platform'] = 'windows'
                          basic_hosts[2][:custom_answers] = { :q_custom => 'LOOKLOOKLOOK' }
                          basic_hosts }
    let( :answers )     { Beaker::Answers.create(@ver, hosts, options) }
    let( :upgrade_answers )     { Beaker::Answers.create(@ver, hosts, options.merge( {:type => :upgrade}) ) }

    before :each do
      @ver = '3.0'
      @answers = answers.answers
    end

    it 'uses simple answers for upgrade from 3.0.x to 3.0.x' do
      @upgrade_answers = upgrade_answers.answers
      expect( @upgrade_answers ).to be === { "vm2"=>{ :q_install=>"y", :q_install_vendor_packages=>"y" }, "vm1"=>{ :q_install=>"y", :q_install_vendor_packages=>"y" }, "vm3"=>{ :q_install=>"y", :q_install_vendor_packages=>"y", :q_custom=>"LOOKLOOKLOOK" } }
    end

    it 'sets correct answers for an agent' do
      @ver = '3.0'
      expect( @answers['vm3'] ).to be === { :q_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_verify_packages=>"y", :q_puppet_symlinks_install=>"y", :q_puppetagent_certname=>hosts[2], :q_puppetagent_server=>hosts[0], :q_puppetmaster_install=>"n", :q_all_in_one_install=>"n", :q_puppet_enterpriseconsole_install=>"n", :q_puppetdb_install=>"n", :q_database_install=>"n", :q_custom=>"LOOKLOOKLOOK" }
    end

    it 'sets correct answers for a master' do
      @ver = '3.0'
      expect( @answers['vm1'] ).to be === { :q_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_verify_packages=>"y", :q_puppet_symlinks_install=>"y", :q_puppetagent_certname=>hosts[0], :q_puppetagent_server=>hosts[0], :q_puppetmaster_install=>"y", :q_all_in_one_install=>"y", :q_puppet_enterpriseconsole_install=>"y", :q_puppetdb_install=>"y", :q_database_install=>"y", :q_puppetdb_hostname=>hosts[0], :q_puppetdb_port=>8081, :q_puppetmaster_dnsaltnames=>"#{hosts[0]},#{hosts[0][:ip]},puppet", :q_puppetmaster_enterpriseconsole_hostname=>hosts[0], :q_puppetmaster_enterpriseconsole_port=>443, :q_puppetmaster_certname=>hosts[0], :q_puppetdb_database_name=>"pe-puppetdb", :q_puppetdb_database_user=>"mYpdBu3r", :q_puppetdb_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_auth_database_name=>"console_auth", :q_puppet_enterpriseconsole_auth_database_user=>"mYu7hu3r", :q_puppet_enterpriseconsole_auth_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_database_name=>"console", :q_puppet_enterpriseconsole_database_user=>"mYc0nS03u3r", :q_puppet_enterpriseconsole_database_password=>"'~!@\#$%^*-/ aZ'", :q_database_host=>hosts[0], :q_database_port=>5432, :q_pe_database=>"y", :q_puppet_enterpriseconsole_inventory_hostname=>hosts[0], :q_puppet_enterpriseconsole_inventory_certname=>hosts[0], :q_puppet_enterpriseconsole_inventory_dnsaltnames=>hosts[0], :q_puppet_enterpriseconsole_inventory_port=>8140, :q_puppet_enterpriseconsole_master_hostname=>hosts[0], :q_puppet_enterpriseconsole_auth_user_email=>"'admin@example.com'", :q_puppet_enterpriseconsole_auth_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_httpd_port=>443, :q_puppet_enterpriseconsole_smtp_host=>"'vm1'", :q_puppet_enterpriseconsole_smtp_use_tls=>"'n'", :q_puppet_enterpriseconsole_smtp_port=>"'25'", :q_database_root_password=>"'=ZYdjiP3jCwV5eo9s1MBd'", :q_database_root_user=>"pe-postgres" }
    end

    it 'generates nil answers for a windows host' do
      @ver = '3.0'
      expect( @answers['vm2'] ).to be === nil
    end

    it 'should add answers to the host objects' do
      @ver = '3.0'
      a = answers.answers
      hosts.each do |host|
        expect( host[:answers] ).to be === @answers[host.name]
      end
    end

    it 'appends custom answers to generated answers' do
      expect( hosts[2][:custom_answers] ).to be == { :q_custom => 'LOOKLOOKLOOK' }
      expect( @answers['vm3'] ).to include :q_custom
      expect( hosts[2][:answers] ).to include :q_custom
    end
  end

  describe Version28 do
    let( :options )     { Beaker::Options::Presets.new.presets }
    let( :basic_hosts ) { make_hosts( { 'pe_ver' => @ver } ) }
    let( :hosts )       { basic_hosts[0]['roles'] = ['master', 'database', 'dashboard']
                          basic_hosts[1]['platform'] = 'windows'
                          basic_hosts }
    let( :answers )     { Beaker::Answers.create(@ver, hosts, options) }

    before :each do
      @ver = '2.8'
      @answers = answers.answers
    end

    it 'sets correct answers for an agent' do
      expect( @answers['vm3'] ).to be === { :q_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_puppet_symlinks_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_certname=>hosts[2], :q_puppetagent_server=>hosts[0], :q_puppetmaster_install=>"n", :q_puppet_enterpriseconsole_install=>"n" }
    end

    it 'sets correct answers for a master' do
      expect( @answers['vm1'] ).to be === { :q_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_puppet_symlinks_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_certname=>hosts[0], :q_puppetagent_server=>hosts[0], :q_puppetmaster_install=>"y", :q_puppet_enterpriseconsole_install=>"y", :q_puppetmaster_certname=>hosts[0], :q_puppetmaster_dnsaltnames=>"#{hosts[0]},#{hosts[0][:ip]},puppet", :q_puppetmaster_enterpriseconsole_hostname=>hosts[0], :q_puppetmaster_enterpriseconsole_port=>443, :q_puppetmaster_forward_facts=>"y", :q_puppet_enterpriseconsole_database_install=>"y", :q_puppet_enterpriseconsole_auth_database_name=>"console_auth", :q_puppet_enterpriseconsole_auth_database_user=>"mYu7hu3r", :q_puppet_enterpriseconsole_auth_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_database_name=>"console", :q_puppet_enterpriseconsole_database_user=>"mYc0nS03u3r", :q_puppet_enterpriseconsole_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_inventory_hostname=>hosts[0], :q_puppet_enterpriseconsole_inventory_certname=>hosts[0], :q_puppet_enterpriseconsole_inventory_dnsaltnames=>hosts[0], :q_puppet_enterpriseconsole_inventory_port=>8140, :q_puppet_enterpriseconsole_master_hostname=>hosts[0], :q_puppet_enterpriseconsole_auth_user_email=>"'admin@example.com'", :q_puppet_enterpriseconsole_auth_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_httpd_port=>443, :q_puppet_enterpriseconsole_smtp_host=>"'vm1'", :q_puppet_enterpriseconsole_smtp_use_tls=>"'n'", :q_puppet_enterpriseconsole_smtp_port=>"'25'", :q_puppet_enterpriseconsole_auth_user=>"'admin@example.com'" }
    end

    it 'generates nil answers for a windows host' do
      expect( @answers['vm2'] ).to be === nil
    end

    it 'should add answers to the host objects' do
      hosts.each do |host|
        expect( host[:answers] ).to be === @answers[host.name]
      end
    end

  end
  describe Version20 do
    let( :options )     { Beaker::Options::Presets.new.presets }
    let( :basic_hosts ) { make_hosts( { 'pe_ver' => @ver } ) }
    let( :hosts )       { basic_hosts[0]['roles'] = ['master', 'database', 'dashboard']
                          basic_hosts[1]['platform'] = 'windows'
                          basic_hosts }

    let( :answers )     { Beaker::Answers.create(@ver, hosts, options) }

    before :each do
      @ver = '2.0'
      @answers = answers.answers
    end

    it 'sets correct answers for an agent' do
      expect( @answers['vm3'] ).to be === { :q_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_puppet_symlinks_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_certname=>hosts[2], :q_puppetagent_server=>hosts[0], :q_puppetmaster_install=>"n", :q_puppet_enterpriseconsole_install=>"n" }
    end

    it 'sets correct answers for a master' do
      expect( @answers['vm1'] ).to be === { :q_install=>"y", :q_puppetagent_install=>"y", :q_puppet_cloud_install=>"y", :q_puppet_symlinks_install=>"y", :q_vendor_packages_install=>"y", :q_puppetagent_certname=>hosts[0], :q_puppetagent_server=>hosts[0], :q_puppetmaster_install=>"y", :q_puppet_enterpriseconsole_install=>"y", :q_puppetmaster_certname=>hosts[0], :q_puppetmaster_dnsaltnames=>"#{hosts[0]},#{hosts[0][:ip]},puppet", :q_puppetmaster_enterpriseconsole_hostname=>hosts[0], :q_puppetmaster_enterpriseconsole_port=>443, :q_puppetmaster_forward_facts=>"y", :q_puppet_enterpriseconsole_database_install=>"y", :q_puppet_enterpriseconsole_auth_database_name=>"console_auth", :q_puppet_enterpriseconsole_auth_database_user=>"mYu7hu3r", :q_puppet_enterpriseconsole_auth_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_database_name=>"console", :q_puppet_enterpriseconsole_database_user=>"mYc0nS03u3r", :q_puppet_enterpriseconsole_database_root_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_database_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_inventory_hostname=>hosts[0], :q_puppet_enterpriseconsole_inventory_certname=>hosts[0], :q_puppet_enterpriseconsole_inventory_dnsaltnames=>hosts[0], :q_puppet_enterpriseconsole_inventory_port=>8140, :q_puppet_enterpriseconsole_master_hostname=>hosts[0], :q_puppet_enterpriseconsole_auth_user_email=>"'admin@example.com'", :q_puppet_enterpriseconsole_auth_password=>"'~!@\#$%^*-/ aZ'", :q_puppet_enterpriseconsole_httpd_port=>443, :q_puppet_enterpriseconsole_smtp_host=>"'vm1'", :q_puppet_enterpriseconsole_smtp_use_tls=>"'n'", :q_puppet_enterpriseconsole_smtp_port=>"'25'", :q_puppet_enterpriseconsole_auth_user=>"'admin@example.com'" }
    end

    it 'generates nil answers for a windows host' do
      expect( @answers['vm2'] ).to be === nil
    end

    it 'should add answers to the host objects' do
      hosts.each do |host|
        expect( host[:answers] ).to be === @answers[host.name]
      end
    end
  end

  describe 'Customization' do
    let( :basic_hosts ) { make_hosts( { 'pe_ver' => @ver } ) }
    let( :options )     { Beaker::Options::Presets.new.presets }
    let( :hosts )       { basic_hosts[0]['roles'] = ['master', 'database', 'dashboard']
                          basic_hosts[1]['platform'] = 'windows'
                          basic_hosts }
    let( :answers )     { Beaker::Answers.create(@ver, hosts, options) }

    def test_answer_customization(answer_key, value_to_set)
      @ver = '3.0'
      options[:answers][answer_key] = value_to_set
      host_answers = answers.answers['vm1']
      expect( host_answers[answer_key] ).to be === value_to_set
    end

    it 'sets :q_puppetdb_hostname' do
      test_answer_customization(:q_puppetdb_hostname, 'q_puppetdb_hostname_custom01')
    end

    it 'sets :q_puppetdb_database_user' do
      test_answer_customization(:q_puppetdb_database_user, 'q_puppetdb_database_user_custom02')
    end

    it 'sets :q_puppetdb_database_password' do
      test_answer_customization(:q_puppetdb_database_password, 'q_puppetdb_database_password_custom03')
    end

    it 'sets :q_puppet_enterpriseconsole_auth_database_password' do
      answer = 'q_puppet_enterpriseconsole_auth_database_password_custom04'
      test_answer_customization(:q_puppet_enterpriseconsole_auth_database_password, answer)
    end

    it 'sets :q_puppet_enterpriseconsole_database_user' do
      answer = 'q_puppet_enterpriseconsole_database_user_custom05'
      test_answer_customization(:q_puppet_enterpriseconsole_database_user, answer)
    end

    it 'sets :q_puppet_enterpriseconsole_database_password' do
      answer = 'q_puppet_enterpriseconsole_database_password_custom06'
      test_answer_customization(:q_puppet_enterpriseconsole_database_password, answer)
    end

    it 'sets :q_database_host' do
      test_answer_customization(:q_database_host, 'q_database_host_custom07')
    end

    it 'sets :q_database_install' do
      test_answer_customization(:q_database_install, 'q_database_install_custom08')
    end

    it 'sets :q_pe_database' do
      test_answer_customization(:q_pe_database, 'q_pe_database_custom08')
    end

  end
end
