module Beaker
  module Shared
    module Repetition

      def repeat_for seconds, &block
        # do not peg CPU if &block takes less than 1 second
        repeat_for_and_wait seconds, 1, &block
      end

      def repeat_for_and_wait seconds, wait
        timeout = Time.now + seconds
        done = false
        until done or timeout < Time.now do
          done = yield
          sleep wait unless done
        end
        return done
      end

      def repeat_fibonacci_style_for attempts
        done = false
        attempt = 1
        last_wait, wait = 0, 1
        while not done and attempt <= attempts do
          done = yield
          attempt += 1
          sleep wait unless done
          last_wait, wait = wait, last_wait + wait
        end
        return done
      end
    end
  end
end

