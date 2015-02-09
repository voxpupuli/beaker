module Beaker
  # This class provides methods for generating PE answer file
  # information.
  class Answers

    # When given a Puppet Enterprise version, a list of hosts and other
    # qualifying data this method will return the appropriate object that can be used
    # to generate answer file data.
    #
    # @param [String] version Puppet Enterprise version to generate answer data for
    # @param [Array<Beaker::Host>] hosts An array of host objects.
    # @param [Hash] options options for answer files
    # @option options [Symbol] :type Should be one of :upgrade or :install.
    # @return [Hash] A hash (keyed from hosts) containing hashes of answer file
    #   data.
    def self.create version, hosts, options
      case version
      when /\A4\.0/
        return Version34.new(version, hosts, options)
      when /\A3\.99/
        return Version40.new(version, hosts, options)
      when /\A3\.7/
        return Version34.new(version, hosts, options)
      when /\A3\.4/
        return Version34.new(version, hosts, options)
      when /\A3\.[2-3]/
        return Version32.new(version, hosts, options)
      when /\A3\.1/
        return Version30.new(version, hosts, options)
      when /\A3\.0/
        return Version30.new(version, hosts, options)
      when /\A2\.8/
        return Version28.new(version, hosts, options)
      when /\A2\.0/
        return Version20.new(version, hosts, options)
      else
        raise NotImplementedError, "Don't know how to generate answers for #{version}"
      end
    end

    # The answer value for a provided question.  Use the user answer when available, otherwise return the default
    # @param [Hash] options options for answer file
    # @option options [Symbol] :answer Contains a hash of user provided question name and answer value pairs.
    # @param [String] default Should there be no user value for the provided question name return this default
    # @return [String] The answer value
    def answer_for(options, q, default = nil)
      options[:answers][q] ? options[:answers][q] : default
    end

    # When given a Puppet Enterprise version, a list of hosts and other
    # qualifying data this method will return a hash (keyed from the hosts)
    # of default Puppet Enterprise answer file data hashes.
    #
    # @param [String] version Puppet Enterprise version to generate answer data for
    # @param [Array<Beaker::Host>] hosts An array of host objects.
    # @param [Hash] options options for answer files
    # @option options [Symbol] :type Should be one of :upgrade or :install.
    # @return [Hash] A hash (keyed from hosts) containing hashes of answer file
    #   data.
    def initialize(version, hosts, options)
      @version = version
      @hosts = hosts
      @options = options
    end

    # Generate the answers hash based upon version, host and option information
    def generate_answers
      raise "This should be handled by subclasses!"
    end

    # Access the answers hash for this version, host and option information.  If the answers
    # have not yet been calculated, generate them.
    # @return [Hash] A hash of answers keyed by host.name
    def answers
      @answers ||= generate_answers
    end

    # This converts a data hash provided by answers, and returns a Puppet
    # Enterprise compatible answer file ready for use.
    #
    # @param [Beaker::Host] host Host object in question to generate the answer
    #   file for.
    # @return [String] a string of answers
    # @example Generating an answer file for a series of hosts
    #   hosts.each do |host|
    #     answers = Beaker::Answers.new("2.0", hosts, "master")
    #     create_remote_file host, "/mypath/answer", answers.answer_string(host, answers)
    #  end
    def answer_string(host)
      answers[host.name].map { |k,v| "#{k}=#{v}" }.join("\n")
    end

  end

  [ 'version40', 'version34', 'version32', 'version30', 'version28', 'version20' ].each do |lib|
    require "beaker/answers/#{lib}"
  end
end
