[ 'version30', 'version28', 'version20' ].each do |file|
  begin
    require "beaker/answers/#{file}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), 'answers', file))
  end
end

module Beaker
  module Answers

    def self.answers(version, hosts, master_certname, options)

      case version
        when /\A3\.1/
          Version30.answers(hosts, master_certname, options) # 3.1 matches 3.0 
        when /\A3\.0/
          Version30.answers(hosts, master_certname, options)
        when /\A2\.8/
          Version28.answers(hosts, master_certname, options)
        when /\A2\.0/
          Version20.answers(hosts, master_certname, options)
        else
          raise NotImplementedError, "Don't know how to generate answers for #{version}"
      end
    end

    def self.answer_string(host, answers)
      answers[host.name].map { |k,v| "#{k}=#{v}" }.join("\n")
    end

  end
end
