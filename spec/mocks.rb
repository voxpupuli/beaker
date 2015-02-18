require 'rspec/mocks'

class MockIO < IO
  def initialize
  end

  methods.each do |meth|
    define_method(:meth) {}
  end

  def === other
    super other
  end
end

module MockNet
  class HTTP

    class Response
      class ResponseHash
        def []key
          if key == "domain"
            nil
          else
            { 'ok' => true, 'hostname' => 'pool' }
          end
        end

      end

      def body
        ResponseHash.new
      end

    end

    class Post
      def initialize uri
        @uri = uri
      end

      def body= *args
        hash
      end
    end

    class Delete
      def initialize uri
        @uri = uri
      end
    end

    def initialize host, port
      @host = host
      @port = port
    end

    def request req
      Response.new
    end
  end

end

module FakeHost
  include RSpec::Mocks::TestDouble

  def self.create(name = 'fakevm', platform = 'redhat-version-arch', options = {})
    options_hash = Beaker::Options::OptionsHash.new.merge(options)
    options_hash['HOSTS'] = { name => { 'platform' => Beaker::Platform.new(platform) } }
    host = Beaker::Host.create(name, options_hash)
    host.extend(MockedExec)
    host
  end

  module MockedExec
    def self.extended(other)
      other.instance_eval do
        send(:instance_variable_set, :@commands, [])
      end
    end

    attr_accessor :commands

    def port_open?(port)
      true
    end

    def any_exec_result
      RSpec::Mocks::Double.new('exec-result').as_null_object
    end

    def exec(command, options = {})
      commands << command
      any_exec_result
    end

    def command_strings
      commands.map { |c| [c.command, c.args].join(' ') }
    end
  end

  def log_prefix
    "FakeHost"
  end
end
