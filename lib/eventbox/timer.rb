class Eventbox
  # Simple timer services for Eventboxes
  #
  # This module can be included into Eventbox classes to add simple timer functions.
  #
  #   class MyBox < Eventbox
  #     include Eventbox::Timer
  #
  #     async_call def init
  #       super # make sure Timer.init is called
  #       timer_after(1) do
  #         puts "one second elapsed"
  #       end
  #     end
  #   end
  #
  # The main functions are timer_after and timer_every.
  # They schedule asynchronous calls to the given block:
  #   timer_after(3) do
  #     # executed in 3 seconds
  #   end
  #
  #   timer_every(3) do
  #     # executed every 3 seconds
  #   end
  #
  # Both functions return an Alarm object which can be used to cancel the alarm through timer_cancel.
  #
  # timer_after, timer_every and timer_cancel can be used within the class, in actions and from external.
  module Timer
    class Reload < RuntimeError
    end

    class Alarm
      include Comparable

      def initialize(ts, &block)
        @timestamp = ts
        @block = block
      end

      def <=>(other)
        @timestamp <=> other
      end

      attr_reader :timestamp
    end

    class OneTimeAlarm < Alarm
      def fire_then_repeat?(now=Time.now)
        @block.call
        false
      end
    end

    class RepeatedAlarm < Alarm
      def initialize(ts, every_seconds, &block)
        super(ts, &block)
        @every_seconds = every_seconds
      end

      def fire_then_repeat?(now=Time.now)
        @block.call
        @timestamp = now + @every_seconds
        true
      end
    end

    extend Boxable

    private async_call def init(*args)
      super
      @timer_alarms = []
      @timer_action = timer_start_worker
    end

    # @private
    private action def timer_start_worker
      loop do
        begin
          interval = timer_next_timestamp&.-(Time.now)
          Thread.handle_interrupt(Reload => :on_blocking) do
            if interval.nil?
              Kernel.sleep
            elsif interval > 0.0
              Kernel.sleep(interval)
            end
          end
        rescue Reload
        else
          timer_fire
        end
      end
    end

    # Schedule a one shot alarm
    #
    # Call the given block after half a second:
    #   timer_after(0.5) do
    #     # executed in 0.5 seconds
    #   end
    sync_call def timer_after(seconds, now=Time.now, &block)
      a = OneTimeAlarm.new(now + seconds, &block)
      timer_add_alarm(a)
      a
    end

    # Schedule a repeated alarm
    #
    # Call the given block in after half a second and then repeatedly every 0.5 seconds:
    #   timer_after(0.5) do
    #     # executed every 0.5 seconds
    #   end
    sync_call def timer_every(seconds, now=Time.now, &block)
      a = RepeatedAlarm.new(now + seconds, seconds, &block)
      timer_add_alarm(a)
      a
    end

    # Cancel an alarm previously scheduled per timer_after or timer_every
    sync_call def timer_cancel(alarm)
      i = @timer_alarms.index(alarm)
      if i
        @timer_alarms.slice!(i)
        if i == @timer_alarms.size
          @timer_action.raise(Reload) unless @timer_action.current?
        end
      end
    end

    # @private
    private def timer_add_alarm(alarm)
      i = @timer_alarms.bsearch_index {|t| t <= alarm }
      if i
        @timer_alarms[i, 0] = alarm
      else
        @timer_alarms << alarm
        @timer_action.raise(Reload) unless @timer_action.current?
      end
    end

    # @private
    private sync_call def timer_next_timestamp
      @timer_alarms[-1]&.timestamp
    end

    # @private
    private sync_call def timer_fire(now=Time.now)
      i = @timer_alarms.bsearch_index {|t| t <= now }
      if i
        due_alarms = @timer_alarms.slice!(i .. -1)
        due_alarms.reverse_each do |a|
          if a.fire_then_repeat?(now)
            timer_add_alarm(a)
          end
        end
      end
      # the method result is irrelevant, but sync_call is necessary to yield the timer blocks
      nil
    end
  end
end