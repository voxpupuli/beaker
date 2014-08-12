require 'beaker/answers/version32'

module Beaker
  module Answers
    module Version34
      def self.answers(hosts, master_certname, options)
        the_answers = Version32.answers(hosts, master_certname, options)
        return the_answers
      end
    end
  end
end
