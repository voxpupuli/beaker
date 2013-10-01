RSpec::Matchers.define :execute_commands_matching do |pattern|

  match do |actual|
    raise(RuntimeError, "Expected #{actual} to be a FakeHost") unless actual.kind_of?(FakeHost)
    @found_count = actual.command_strings.grep(pattern).size
    @times.nil? ?
      @found_count > 0 :
      @found_count == @times
  end

  chain :exactly do |times|
    @times = times
  end

  chain :times do
    # clarity only
  end

  chain :once do
    @times = 1
    # clarity only
  end

  def message(actual, pattern, times, found_count)
      msg = times == 1 ?
        "#{pattern} once" :
        "#{pattern} #{times} times"
      msg += " but instead found a count of #{found_count}" if found_count != times
      msg + " in:\n #{actual.command_strings.pretty_inspect}"
  end

  failure_message_for_should do |actual|
    "Expected to find #{message(actual, pattern, @times, @found_count)}"
  end

  failure_message_for_should_not do |actual|
    "Unexpectedly found #{message(actual, pattern, @times, @found_count)}"
  end
end
