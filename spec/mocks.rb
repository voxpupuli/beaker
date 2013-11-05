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

class FakeHost
  attr_accessor :commands

  def initialize(options = {})
    @pe = options[:pe]
    @commands = []
  end

  def is_pe?
    @pe
  end

  def any_exec_result
    RSpec::Mocks::Mock.new('exec-result').as_null_object
  end

  def exec(command, options = {})
    commands << command
    any_exec_result
  end

  def command_strings
    commands.map { |c| [c.command, c.args].join(' ') }
  end
end
