module Beaker
  module Answers
    module Version20

      def self.host_answers(host, master_certname, master, dashboard, options)
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

        master_a = {
          :q_puppetmaster_install => 'y',
          :q_puppetmaster_certname => master_certname,
          :q_puppetmaster_install => 'y',
          :q_puppetmaster_dnsaltnames => master_certname+",puppet",
          :q_puppetmaster_enterpriseconsole_hostname => dashboard,
          :q_puppetmaster_enterpriseconsole_port => 443,
          :q_puppetmaster_forward_facts => 'y',
        }

        if master['ip']
          master_a[:q_puppetmaster_dnsaltnames]+=","+master['ip']
        end

        dashboard_user = "'#{ENV['q_puppet_enterpriseconsole_auth_user_email'] || 'admin@example.com'}'"
        smtp_host = "'#{ENV['q_puppet_enterpriseconsole_smtp_host'] || dashboard}'"
        dashboard_password = ENV['q_puppet_enterpriseconsole_auth_password'] || '~!@#$%^*-/ aZ'
        smtp_port = "'#{ENV['q_puppet_enterpriseconsole_smtp_port'] || 25}'"
        smtp_username = ENV['q_puppet_enterpriseconsole_smtp_username']
        smtp_password = ENV['q_puppet_enterpriseconsole_smtp_password']
        smtp_use_tls = "'#{ENV['q_puppet_enterpriseconsole_smtp_use_tls'] || 'n'}'"

        console_a = {
          :q_puppet_enterpriseconsole_install => 'y',
          :q_puppet_enterpriseconsole_database_install => 'y',
          :q_puppet_enterpriseconsole_auth_database_name => 'console_auth',
          :q_puppet_enterpriseconsole_auth_database_user => 'mYu7hu3r',
          :q_puppet_enterpriseconsole_auth_database_password => "'#{dashboard_password}'",
          :q_puppet_enterpriseconsole_database_name => 'console',
          :q_puppet_enterpriseconsole_database_user => 'mYc0nS03u3r',
          :q_puppet_enterpriseconsole_database_root_password => "'#{dashboard_password}'",
          :q_puppet_enterpriseconsole_database_password => "'#{dashboard_password}'",
          :q_puppet_enterpriseconsole_inventory_hostname => host,
          :q_puppet_enterpriseconsole_inventory_certname => host,
          :q_puppet_enterpriseconsole_inventory_dnsaltnames => master,
          :q_puppet_enterpriseconsole_inventory_port => 8140,
          :q_puppet_enterpriseconsole_master_hostname => master,

          :q_puppet_enterpriseconsole_auth_user_email => dashboard_user,
          :q_puppet_enterpriseconsole_auth_password => "'#{dashboard_password}'",

          :q_puppet_enterpriseconsole_httpd_port => 443,

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

      def self.answers(hosts, master_certname, options)
        the_answers = {}
        dashboard = only_host_with_role(hosts, 'dashboard')
        master = only_host_with_role(hosts, 'master')
        hosts.each do |h|
            the_answers[h.name] = host_answers(h, master_certname, master, dashboard, options)
        end
        return the_answers
      end

    end
  end
end
