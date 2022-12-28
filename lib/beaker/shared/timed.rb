module Beaker
  module Shared
    module Timed

      def run_and_report_duration
        start = Time.now
        yield
        Time.now - start
      end

    end
  end
end

