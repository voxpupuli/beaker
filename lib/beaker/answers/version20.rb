module Beaker
  # This class provides answer file information for PE version 2.0
  #
  # @api private
  class Version20 < Answers
    # Return answer data for a host
    #
    # @param [Beaker::Host] host Host to return data for
    # @param [Beaker::Host] master Host object representing the master
    # @param [Beaker::Host] dashboard Host object representing the dashboard
    # @param [Hash] options options for answer files
    # @option options [Symbol] :type Should be one of :upgrade or :install.
    # @return [Hash] A hash (keyed from hosts) containing hashes of answer file
    #   data.
    def host_answers(host, master, dashboard, options)
      return nil if host['platform'] =~ /windows/

      agent_a = {
        :q_install => 'y',
        :q_puppetagent_install => 'y',
        :q_puppet_cloud_install => 'y',
        :q_puppet_symlinks_install => 'y',
        :q_vendor_packages_install => 'y',
        :q_puppetagent_certname => host,
        :q_puppetagent_server => master,

        # Disable console and master by default
        # This will be overridden by other blocks being merged in
        :q_puppetmaster_install => 'n',
        :q_puppet_enterpriseconsole_install => 'n',
      }

      master_dns_altnames = [master.to_s, master['ip'], 'puppet'].compact.uniq.join(',')
      master_a = {
        :q_puppetmaster_install => 'y',
        :q_puppetmaster_certname => master,
        :q_puppetmaster_install => 'y',
        :q_puppetmaster_dnsaltnames => master_dns_altnames,
        :q_puppetmaster_enterpriseconsole_hostname => dashboard,
        :q_puppetmaster_enterpriseconsole_port => answer_for(options, :q_puppetmaster_enterpriseconsole_port, 443),
        :q_puppetmaster_forward_facts => 'y',
      }

      dashboard_user = "'#{answer_for(options, :q_puppet_enterpriseconsole_auth_user_email)}'"
      smtp_host = "'#{answer_for(options, :q_puppet_enterpriseconsole_smtp_host, dashboard)}'"
      dashboard_password = "'#{answer_for(options, :q_puppet_enterpriseconsole_auth_password)}'"
      smtp_port = "'#{answer_for(options, :q_puppet_enterpriseconsole_smtp_port)}'"
      smtp_username = answer_for(options, :q_puppet_enterpriseconsole_smtp_username)
      smtp_password = answer_for(options, :q_puppet_enterpriseconsole_smtp_password)
      smtp_use_tls = "'#{answer_for(options, :q_puppet_enterpriseconsole_smtp_use_tls)}'"
      auth_database_name = answer_for(options, :q_puppet_enterpriseconsole_auth_database_name, 'console_auth')
      auth_database_user = answer_for(options, :q_puppet_enterpriseconsole_auth_database_user, 'mYu7hu3r')
      console_database_name = answer_for(options, :q_puppet_enterpriseconsole_database_name, 'console')
      console_database_user = answer_for(options, :q_puppet_enterpriseconsole_database_user, 'mYc0nS03u3r')
      console_inventory_port = answer_for(options, :q_puppet_enterpriseconsole_inventory_port, 8140)
      console_httpd_port = answer_for(options, :q_puppet_enterpriseconsole_httpd_port, 443)

      console_a = {
        :q_puppet_enterpriseconsole_install => 'y',
        :q_puppet_enterpriseconsole_database_install => 'y',
        :q_puppet_enterpriseconsole_auth_database_name => auth_database_name,
        :q_puppet_enterpriseconsole_auth_database_user => auth_database_user,
        :q_puppet_enterpriseconsole_auth_database_password => dashboard_password,
        :q_puppet_enterpriseconsole_database_name => console_database_name,
        :q_puppet_enterpriseconsole_database_user => console_database_user,
        :q_puppet_enterpriseconsole_database_root_password => dashboard_password,
        :q_puppet_enterpriseconsole_database_password => dashboard_password,
        :q_puppet_enterpriseconsole_inventory_hostname => host,
        :q_puppet_enterpriseconsole_inventory_certname => host,
        :q_puppet_enterpriseconsole_inventory_dnsaltnames => master,
        :q_puppet_enterpriseconsole_inventory_port => console_inventory_port,
        :q_puppet_enterpriseconsole_master_hostname => master,
        :q_puppet_enterpriseconsole_auth_user_email => dashboard_user,
        :q_puppet_enterpriseconsole_auth_password => dashboard_password,
        :q_puppet_enterpriseconsole_httpd_port => console_httpd_port,
        :q_puppet_enterpriseconsole_smtp_host => smtp_host,
        :q_puppet_enterpriseconsole_smtp_use_tls => smtp_use_tls,
        :q_puppet_enterpriseconsole_smtp_port => smtp_port,
      }

      console_a[:q_puppet_enterpriseconsole_auth_user] = console_a[:q_puppet_enterpriseconsole_auth_user_email]

      if smtp_password and smtp_username
        console_a.merge!({
                           :q_puppet_enterpriseconsole_smtp_password => "'#{smtp_password}'",
                           :q_puppet_enterpriseconsole_smtp_username => "'#{smtp_username}'",
                           :q_puppet_enterpriseconsole_smtp_user_auth => 'y'
                         })
      end

      answers = agent_a.dup
      if host == master
        answers.merge! master_a
      end

      if host == dashboard
        answers.merge! console_a
      end

      return answers
    end

    # Return answer data for all hosts.
    #
    # @return [Hash] A hash (keyed from hosts) containing hashes of answer file
    #   data.
    def generate_answers
      the_answers = {}
      dashboard = only_host_with_role(@hosts, 'dashboard')
      master = only_host_with_role(@hosts, 'master')
      @hosts.each do |h|
        the_answers[h.name] = host_answers(h, master, dashboard, @options)
        if h[:custom_answers]
          the_answers[h.name] = the_answers[h.name].merge(h[:custom_answers])
        end
        h[:answers] = the_answers[h.name]
      end
      return the_answers
    end
  end
end
