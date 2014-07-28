require 'beaker/answers/version32'

module Beaker
  module Answers
    module Version34
      def self.answers(hosts, master_certname, options)
        master = only_host_with_role(hosts, 'master')

        the_answers = Version32.answers(hosts, master_certname, options)
        the_answers[master.name][:q_jvm_puppetmaster] = 'y'

        return the_answers
      end
    end
  end
end
