require 'beaker/answers/version30'

module Beaker
  module Answers
    module Version32
      def self.answers(hosts, master_certname, options)
        dashboard = only_host_with_role(hosts, 'dashboard')
        master = only_host_with_role(hosts, 'master')

        the_answers = Version30.answers(hosts, master_certname, options)
        if dashboard != master
          # in 3.2, dashboard needs the master certname
          the_answers[dashboard.name][:q_puppetmaster_certname] = master_certname
        end

        return the_answers
      end
    end
  end
end
