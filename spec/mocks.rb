require 'rspec/mocks'

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

      def body= *_args
        hash
      end
    end

    class Put
      def initialize uri
        @uri = uri
      end

      def body= *_args
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

    def request _req
      Response.new
    end
  end

end

module FakeHost
  include RSpec::Mocks::TestDouble

  def self.create(name = 'fakevm', platform = 'redhat-version-arch', options = {})
    options_hash = Beaker::Options::OptionsHash.new.merge(options)
    options_hash[:logger] = RSpec::Mocks::Double.new('logger').as_null_object
    host = Beaker::Host.create(name, { 'platform' => Beaker::Platform.new(platform) } , options_hash)
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

    def port_open?(_port)
      true
    end

    def any_exec_result
      RSpec::Mocks::Double.new('exec-result').as_null_object
    end

    def exec(command, _options = {})
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
