require_relative "../test_helper"

class EventboxTimerTest < Minitest::Test
  # Fake time disturbs guard_time observer
  Eventbox = Eventbox.with_options(guard_time: nil)

  def diff_time
    st = Time.now
    yield
    Time.now - st
  end

  def test_delay_init
    eb = Class.new(Eventbox) do
      include Eventbox::Timer
      yield_call def init(interval, result)
        super()
        timer_after(interval) do
          result.yield
        end
      end
    end

    dt = diff_time { eb.new(0.01).shutdown! }
    assert_operator dt, :>=, 0.01
  end

  def test_after
    eb = Class.new(Eventbox) do
      include Eventbox::Timer

      yield_call def run(result)
        alerts = []
        timer_after(6) do
          alerts << 6
        end
        timer_after(2) do
          alerts << 2
          timer_after(1) do
            alerts << 1
          end
        end
        timer_after(4) do
          alerts << 4
        end
        timer_after(8) do
          result.yield alerts
        end
      end
    end.new

    with_fake_time do
      alerts = eb.run
      assert_equal [2, 1, 4, 6], alerts
      eb.shutdown!
    end
  end

  def test_every
    eb = Class.new(Eventbox) do
      include Eventbox::Timer

      yield_call def run(result)
        alerts = []
        timer_after(6) do
          alerts << 6
        end
        timer_every(2) do
          alerts << 2
          timer_after(1) do
            alerts << 1
          end
        end
        timer_after(4) do
          alerts << 4
        end
        timer_after(8) do
          result.yield alerts
        end
      end
    end.new

    with_fake_time do
      alerts = eb.run
      assert_equal [2, 1, 4, 2, 1, 6, 2, 1], alerts
      eb.shutdown!
    end
  end

  def test_cancel
    eb = Class.new(Eventbox) do
      include Eventbox::Timer

      yield_call def run(result)
        alerts = []
        timer_after(6) do
          alerts << 6
        end
        a1 = timer_every(2) do
          alerts << 2
          timer_after(1) do
            alerts << 1
          end
        end
        timer_after(5) do
          alerts << 5
          timer_cancel(a1)
        end
        timer_after(8) do
          result.yield alerts
        end
      end
    end.new

    with_fake_time do
      alerts = eb.run
      assert_equal [2, 1, 2, 5, 1, 6], alerts
      eb.shutdown!
    end
  end

  def test_cancel_with_retrigger
    eb = Class.new(Eventbox) do
      include Eventbox::Timer

      yield_call def run(result)
        alerts = []
        a1 = timer_after(2) do
          alerts << 2
        end
        timer_cancel(a1)
        timer_after(8) do
          result.yield alerts
        end
      end
    end.new

    with_fake_time do
      alerts = eb.run
      assert_equal [], alerts
      eb.shutdown!
    end
  end

  def test_all_repeated
    20.times do
      test_after
      test_cancel
      test_cancel_with_retrigger
      test_delay_init
      test_every
    end
  end
end
