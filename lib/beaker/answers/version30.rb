module Beaker
  # This class provides answer file information for PE version 3.x
  #
  # @api private
  class Version30 < Answers
    # Return answer data for a host
    #
    # @param [Beaker::Host] host Host to return data for
    # @param [Beaker::Host] master Host object representing the master
    # @param [Beaker::Host] dashboard Host object representing the dashboard
    # @param [Hash] options options for answer files
    # @option options [Symbol] :type Should be one of :upgrade or :install.
    # @return [Hash] A hash (keyed from hosts) containing hashes of answer file
    #   data.
    def host_answers(host, master, database, dashboard, options)
      # Windows hosts don't have normal answers...
      return nil if host['platform'] =~ /windows/
      masterless = options[:masterless]

      # Everything's an agent
      agent_a = {
        :q_puppetagent_install => answer_for(options, :q_puppetagent_install, 'y'),
        :q_puppet_cloud_install => answer_for(options, :q_puppet_cloud_install, 'y'),
        :q_verify_packages => answer_for(options, :q_verify_packages, 'y'),
        :q_puppet_symlinks_install => answer_for(options, :q_puppet_symlinks_install, 'y'),
        :q_puppetagent_certname => answer_for(options, :q_puppetagent_certname, host.to_s),

        # Disable database, console, and master by default
        # This will be overridden by other blocks being merged in.
        :q_puppetmaster_install => answer_for(options, :q_puppetmaster_install, 'n'),
        :q_all_in_one_install => answer_for(options, :q_all_in_one_install, 'n'),
        :q_puppet_enterpriseconsole_install => answer_for(options, :q_puppet_enterpriseconsole_install, 'n'),
        :q_puppetdb_install => answer_for(options, :q_puppetdb_install, 'n'),
        :q_database_install => answer_for(options, :q_database_install, 'n'),
      }
      agent_a[:q_puppetagent_server] = masterless ? host.to_s : master.to_s
      agent_a[:q_continue_or_reenter_master_hostname] = 'c' if masterless

      # These base answers are needed by all
      common_a = {
        :q_install => answer_for(options, :q_install, 'y'),
        :q_vendor_packages_install => answer_for(options, :q_vendor_packages_install, 'y'),
      }

      unless masterless
        # master/database answers
        master_database_a = {
          :q_puppetmaster_certname => answer_for(options, :q_puppetmaster_certname, master.to_s)
        }

        # Master/dashboard answers
        master_console_a = {
          :q_puppetdb_hostname  => answer_for(options, :q_puppetdb_hostname, database.to_s),
          :q_puppetdb_port      => answer_for(options, :q_puppetdb_port, 8081)
        }

        # Master only answers
        master_dns_altnames = [master.to_s, master['ip'], 'puppet'].compact.uniq.join(',')
        master_a = {
          :q_puppetmaster_install => answer_for(options, :q_puppetmaster_install, 'y'),
          :q_puppetmaster_dnsaltnames => master_dns_altnames,
          :q_puppetmaster_enterpriseconsole_hostname => answer_for(options, :q_puppetmaster_enterpriseconsole_hostname, dashboard.to_s),
          :q_puppetmaster_enterpriseconsole_port => answer_for(options, :q_puppetmaster_enterpriseconsole_port, 443),
        }

        # Common answers for console and database
        console_auth_password = "'#{answer_for(options, :q_puppet_enterpriseconsole_auth_password)}'"
        puppetdb_database_name = answer_for(options, :q_puppetdb_database_name, 'pe-puppetdb')
        puppetdb_database_user = answer_for(options, :q_puppetdb_database_user, 'mYpdBu3r')
        puppetdb_database_password = answer_for(options, :q_puppetdb_database_password, "'#{answer_for(options, :q_puppetdb_password)}'")
        console_auth_database_name = answer_for(options, :q_puppet_enterpriseconsole_auth_database_name, 'console_auth')
        console_auth_database_user = answer_for(options, :q_puppet_enterpriseconsole_auth_database_user, 'mYu7hu3r')
        console_auth_database_password = answer_for(options, :q_puppet_enterpriseconsole_auth_database_password, console_auth_password)
        console_database_name = answer_for(options, :q_puppet_enterpriseconsole_database_name, 'console')
        console_database_user = answer_for(options, :q_puppet_enterpriseconsole_database_user, 'mYc0nS03u3r')
        console_database_host = answer_for(options, :q_database_host, database.to_s)
        console_database_port = answer_for(options, :q_database_port, 5432)
        console_database_password = answer_for(options, :q_puppet_enterpriseconsole_database_password, console_auth_password)

        console_database_a = {
          :q_puppetdb_database_name => puppetdb_database_name,
          :q_puppetdb_database_user => puppetdb_database_user,
          :q_puppetdb_database_password => puppetdb_database_password,
          :q_puppet_enterpriseconsole_auth_database_name => console_auth_database_name,
          :q_puppet_enterpriseconsole_auth_database_user => console_auth_database_user,
          :q_puppet_enterpriseconsole_auth_database_password => console_auth_database_password,
          :q_puppet_enterpriseconsole_database_name => console_database_name,
          :q_puppet_enterpriseconsole_database_user => console_database_user,
          :q_puppet_enterpriseconsole_database_password => console_database_password,
          :q_database_host => console_database_host,
          :q_database_port => console_database_port,
        }

        # Console only answers
        dashboard_user = "'#{answer_for(options, :q_puppet_enterpriseconsole_auth_user_email)}'"


        console_install = answer_for(options, :q_puppet_enterpriseconsole_install, 'y')
        console_inventory_hostname = answer_for(options, :q_puppet_enterpriseconsole_inventory_hostname, host.to_s)
        console_inventory_certname = answer_for(options, :q_puppet_enterpriseconsole_inventory_certname, host.to_s)
        console_inventory_dnsaltnames = answer_for(options, :q_puppet_enterpriseconsole_inventory_dnsaltnames, dashboard.to_s)
        smtp_host = "'#{answer_for(options, :q_puppet_enterpriseconsole_smtp_host, dashboard.to_s)}'"
        smtp_port = "'#{answer_for(options, :q_puppet_enterpriseconsole_smtp_port)}'"
        smtp_username = answer_for(options, :q_puppet_enterpriseconsole_smtp_username)
        smtp_password = answer_for(options, :q_puppet_enterpriseconsole_smtp_password)
        smtp_use_tls = "'#{answer_for(options, :q_puppet_enterpriseconsole_smtp_use_tls)}'"
        console_inventory_port = answer_for(options, :q_puppet_enterpriseconsole_inventory_port, 8140)
        master_hostname = answer_for(options, :q_puppet_enterpriseconsole_master_hostname, master.to_s)
        console_httpd_port = answer_for(options, :q_puppet_enterpriseconsole_httpd_port, 443)

        console_a = {
          :q_puppet_enterpriseconsole_install => console_install,
          :q_puppet_enterpriseconsole_inventory_hostname => console_inventory_hostname,
          :q_puppet_enterpriseconsole_inventory_certname => console_inventory_certname,
          :q_puppet_enterpriseconsole_inventory_dnsaltnames => console_inventory_dnsaltnames,
          :q_puppet_enterpriseconsole_inventory_port => console_inventory_port,
          :q_puppet_enterpriseconsole_master_hostname => master_hostname,
          :q_puppet_enterpriseconsole_auth_user_email => dashboard_user,
          :q_puppet_enterpriseconsole_auth_password => console_auth_password,
          :q_puppet_enterpriseconsole_httpd_port => console_httpd_port,
          :q_puppet_enterpriseconsole_smtp_host => smtp_host,
          :q_puppet_enterpriseconsole_smtp_use_tls => smtp_use_tls,
          :q_puppet_enterpriseconsole_smtp_port => smtp_port,
        }

        if smtp_password and smtp_username
          console_smtp_user_auth = answer_for(options, :q_puppet_enterpriseconsole_smtp_user_auth, 'y')
          console_a.merge!({
                             :q_puppet_enterpriseconsole_smtp_password => "'#{smtp_password}'",
                             :q_puppet_enterpriseconsole_smtp_username => "'#{smtp_username}'",
                             :q_puppet_enterpriseconsole_smtp_user_auth => console_smtp_user_auth
                           })
        end

        # Database only answers
        database_a = {
          :q_puppetdb_install => answer_for(options, :q_puppetdb_install, 'y'),
          :q_database_install => answer_for(options, :q_database_install, 'y'),
          :q_database_root_password => "'#{answer_for(options, :q_database_root_password, '=ZYdjiP3jCwV5eo9s1MBd')}'",
          :q_database_root_user => answer_for(options, :q_database_root_user, 'pe-postgres'),
        }
      end

      # Special answers for special hosts
      aix_a = {
        :q_run_updtvpkg => answer_for(options, :q_run_updtvpkg, 'y'),
      }

      answers = common_a.dup

      unless options[:type] == :upgrade
        answers.merge! agent_a
      end

      if host == master
        answers.merge! master_console_a
        unless options[:type] == :upgrade
          answers.merge! master_a
          answers.merge! master_database_a
        end
      end

      if host == dashboard
        answers.merge! master_console_a
        answers.merge! console_database_a
        answers[:q_pe_database] = answer_for(options, :q_pe_database, 'y')
        unless options[:type] == :upgrade
          answers.merge! console_a
        else
          answers[:q_database_export_dir] = answer_for(options, :q_database_export_dir, '/tmp')
        end
      end

      if host == database
        if database != master
          if options[:type] == :upgrade
            # This is kinda annoying - if we're upgrading to 3.0 and are
            # puppetdb, we're actually doing a clean install. We thus
            # need the core agent answers.
            answers.merge! agent_a
          end
          answers.merge! master_database_a
        end
        answers.merge! database_a
        answers.merge! console_database_a
      end

      if host == master and host == database and host == dashboard
        answers[:q_all_in_one_install] = 'y'
      end

      if host['platform'].include? 'aix'
        answers.merge! aix_a
      end

      return answers
    end

    # Return answer data for all hosts.
    #
    # @return [Hash] A hash (keyed from hosts) containing hashes of answer file
    #   data.
    def generate_answers
      the_answers = {}
      masterless  = @options[:masterless]
      database    = masterless ? nil : only_host_with_role(@hosts, 'database')
      dashboard   = masterless ? nil : only_host_with_role(@hosts, 'dashboard')
      master      = masterless ? nil : only_host_with_role(@hosts, 'master')
      @hosts.each do |h|
        if @options[:type] == :upgrade and h[:pe_ver] =~ /\A3.0/
          # 3.0.x to 3.0.x should require no answers
          the_answers[h.name] = {
            :q_install => answer_for(@options, :q_install, 'y'),
            :q_install_vendor_packages => answer_for(@options, :q_install_vendor_packages, 'y'),
          }
        else
          the_answers[h.name] = host_answers(h, master, database, dashboard, @options)
        end
        if the_answers[h.name] && h[:custom_answers]
          the_answers[h.name] = the_answers[h.name].merge(h[:custom_answers])
        end
        h[:answers] = the_answers[h.name]
      end
      return the_answers
    end
  end
end
