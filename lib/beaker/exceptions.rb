module Beaker
  # Raised when a command could not be run to completion because the underlying
  # ssh connection failed part way through.
  #
  # Rescue this to catch either failure regardless of whether the remote host
  # had started running the command. Rescue {CommandStartedFailure} or
  # {CommandNotStartedFailure} directly to handle only one of them -- that
  # distinction is the only thing that determines whether a retry is safe.
  #
  # Note that this is deliberately *not* a subclass of
  # {Beaker::Host::CommandFailure}. Plenty of code, both in beaker and in the
  # test suites that use it, does a bare `rescue Beaker::Host::CommandFailure`
  # to mean "this command was allowed to fail" -- and a lost connection is a
  # different thing entirely.
  class CommandExecutionFailure < StandardError; end

  # The connection failed before the remote host confirmed it had started
  # running the command -- the channel never opened, or the remote refused the
  # exec request. Nothing ran over there, so retrying is always safe.
  class CommandNotStartedFailure < CommandExecutionFailure; end

  # The connection failed after the remote host confirmed it had started
  # running the command. It may have run some or all of it before contact was
  # lost, so retrying is only safe if the command is idempotent --
  # `puppet apply` is, `useradd` is not.
  class CommandStartedFailure < CommandExecutionFailure; end
end
