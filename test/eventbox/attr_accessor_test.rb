require_relative "../test_helper"

class EventboxAttrAccessorTest < Minitest::Test
  def test_attr_accessor
    fc = Class.new(Eventbox) do
      sync_call def init
        @percent = 0
      end
      attr_accessor :percent
    end.new

    fc.percent = 10
    assert_equal 10, fc.percent
    fc.percent = "20"
    assert_equal "20", fc.percent
  end

  def test_attr_writer
    fc = Class.new(Eventbox) do
      sync_call def get
        @percent
      end
      attr_writer :percent
    end.new

    fc.percent = 10
    assert_equal 10, fc.get
  end

  def test_attr_reader
    fc = Class.new(Eventbox) do
      async_call def init
        @percent = 10
      end
      attr_reader :percent
    end.new

    assert_equal 10, fc.percent
  end
end
