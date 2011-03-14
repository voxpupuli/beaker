module GenAnswerFiles
  def gen_answer_files(config)

    # Agent base answers
    agent_only_a = %q[
q_install=y
q_puppet_symlinks_install=y
q_puppetagent_certname=`hostname -s`
q_puppetagent_install=y
q_puppetagent_pluginsync=y
q_puppetagent_server=MASTER
q_puppetdashboard_install=n
q_puppetmaster_install=n
q_rubydevelopment_install=n
q_vendor_packages_install=y
  ]

    # Master base answers
    master_only_a = %q[
q_install=y
q_puppet_symlinks_install=y
q_puppetagent_install=n
q_puppetdashboard_install=n
q_puppetmaster_certdnsnames=puppet:`hostname -s`
q_puppetmaster_certname=`hostname -s`
q_puppetmaster_dashboard_hostname=localhost
q_puppetmaster_dashboard_port=3000
q_puppetmaster_install=y
q_puppetmaster_use_dashboard_classifier=y
q_puppetmaster_use_dashboard_reports=y
q_rubydevelopment_install=n
q_vendor_packages_install=y
  ]


    # Master and Dashboard answers
    master_dashboard_a = %q[
q_vendor_packages_install=y
q_install=y
q_puppet_symlinks_install=y
q_puppetagent_install=n
q_puppetmaster_certdnsnames=puppet:`hostname -s`
q_puppetmaster_certname=`hostname -s`
q_puppetmaster_dashboard_hostname=localhost
q_puppetmaster_dashboard_port=3000
q_puppetmaster_install=y
q_puppetmaster_use_dashboard_classifier=n
q_puppetmaster_use_dashboard_reports=y
q_rubydevelopment_install=y
q_puppetdashboard_database_name=dbdb
q_puppetdashboard_database_root_password=puppet
q_puppetdashboard_database_user=puppet
q_puppetdashboard_database_install=y
q_puppetdashboard_database_password=puppet
q_puppetdashboard_httpd_port=3000
q_puppetdashboard_install=y
  ]

    # Agent and Dashboard answers
    agent_dashboard_a = %q[
q_puppetdashboard_database_install=y
q_puppetdashboard_database_password=puppet
q_puppetdashboard_httpd_port=3000
q_puppetdashboard_install=y
q_puppetdashboard_database_name=dbdb
q_puppetdashboard_database_root_password=puppet
q_puppetdashboard_database_user=puppet
q_install=y
q_vendor_packages_install=y
q_puppet_symlinks_install=y
q_puppetagent_certname=`hostname -s`
q_puppetagent_install=y
q_puppetagent_pluginsync=y
q_puppetagent_server=MASTER
q_puppetmaster_install=n
q_puppetagent_graph=y
q_rubydevelopment_install=y
  ]

    # Dashboard only answers
    dashboard_only_a = %q[
q_install='y'
q_puppet_symlinks_install='n'
q_puppetagent_install='n'
q_puppetdashboard_database_install='y'
q_puppetdashboard_database_name='dashboard'
q_puppetdashboard_database_password='puppet'
q_puppetdashboard_database_root_password='puppet'
q_puppetdashboard_database_user='dashboard'
q_puppetdashboard_httpd_port='3000'
q_puppetdashboard_install='y'
q_puppetmaster_install='n'
q_rubydevelopment_install='n'
q_vendor_packages_install='y'
  ]

    master=""

    # Clean up all answer files
    FileUtils.rm Dir.glob('tarballs/q_*')
    FileUtils.rm("tarballs/answers.tar") if File::exists?("tarballs/answers.tar")
    system("tar cf tarballs/answers.tar tarballs/q_*")

    # Parse config for Master
    hosts.each do |host|
      master = host if host['roles'].include? 'master'
    end

    # For all defined hosts...
    hosts.each do |host|
      role_agent=FALSE
      role_master=FALSE
      role_dashboard=FALSE

      role_agent=TRUE     if host['roles'].include? 'agent'
      role_master=TRUE    if host['roles'].include? 'master'
      role_dashboard=TRUE if host['roles'].include? 'dashboard'

      # Host is only a Dashboard
      if !role_agent && !role_master && role_dashboard then
        Log.debug 'host is dashboard only'
        File.open("tarballs/q_dashboard_only", 'w') do |fh|
          dashboard_only_a.split(/\n/).each do |line|    # Insert Puppet master host name
            if line =~ /(q_puppetagent_server=)MASTER/ then
              line = $1+master
            end
            fh.puts line
          end
        end
      end

      # Host is only an Agent
      if role_agent && !role_master && !role_dashboard then
        Log.debug 'host is agent only'
        File.open("tarballs/q_agent_only", 'w') do |fh|
          agent_only_a.split(/\n/).each do |line|    # Insert Puppet master host name
            if line =~ /(q_puppetagent_server=)MASTER/ then
              line = $1+master
            end
            fh.puts line
          end
        end
      end

      # Host is Agent and Dashboard
      if role_agent && !role_master && role_dashboard then
        Log.debug 'host is agent and dashboard'
        File.open("tarballs/q_agent_and_dashboard", 'w') do |fh|
          agent_dashboard_a.split(/\n/).each do |line|
            if line =~ /(q_puppetagent_server=)MASTER/ then
              line = $1+master
            end
            fh.puts line
          end
        end
      end

      # Host is a Master only - no Dashboard
      if !role_agent && role_master && !role_dashboard then
        Log.debug 'host is master only'
        File.open("tarballs/q_master_only", 'w') do |fh|
          master_only_a.split(/\n/).each do |line|
            fh.puts line
          end
        end
      end

      # Host is a Master and Dashboard
      if !role_agent && role_master && role_dashboard then
        Log.debug 'host is master and dashboard'
        File.open("tarballs/q_master_and_dashboard", 'w') do |fh|
          master_dashboard_a.split(/\n/).each do |line|
            fh.puts line
          end
        end
      end

    end
  end
end
