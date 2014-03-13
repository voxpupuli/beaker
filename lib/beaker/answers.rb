[ 'version32', 'version30', 'version28', 'version20' ].each do |file|
  begin
    require "beaker/answers/#{file}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), 'answers', file))
  end
end

module Beaker
  # This module provides static methods for accessing PE answer file
  # information.
  module Answers

    # When given a Puppet Enterprise version, a list of hosts and other
    # qualifying data this method will return a hash (keyed from the hosts)
    # of default Puppet Enterprise answer file data hashes.
    #
    # @param [String] version Puppet Enterprise version to generate answer data for
    # @param [Array<Beaker::Host>] hosts An array of host objects.
    # @param [String] master_certname Hostname of the puppet master.
    # @param [Hash] options options for answer files
    # @option options [Symbol] :type Should be one of :upgrade or :install.
    # @return [Hash] A hash (keyed from hosts) containing hashes of answer file
    #   data.
    def self.answers(version, hosts, master_certname, options)

      case version
      when /\A3\.[2-3]/
        Version32.answers(hosts, master_certname, options)
      when /\A3\.1/
        Version30.answers(hosts, master_certname, options)
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

    # This converts a data hash provided by answers, and returns a Puppet
    # Enterprise compatible answer file ready for use.
    #
    # @param [Beaker::Host] host Host object in question to generate the answer
    #   file for.
    # @param [Hash] answers Answers hash as returned by #answers
    # @return [String] a string of answers
    # @example Generating an answer file for a series of hosts
    #   hosts.each do |host|
    #     answers = Beaker::Answers.answers("2.0", hosts, "master")
    #     create_remote_file host, "/mypath/answer", Beaker::Answers.answer_string(host, answers)
    #  end
    def self.answer_string(host, answers)
      answers[host.name].map { |k,v| "#{k}=#{v}" }.join("\n")
    end

  end
end
