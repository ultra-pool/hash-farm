# -*- encoding : utf-8 -*-

require 'test_helper'

class ListenableTest < ActiveSupport::TestCase

  class FakeListenable
    include Listenable

    def do_emit_sig( *args )
      emit( 'sig', *args )
    end
  end

  setup do
    @listen = FakeListenable.new
  end

  test 'it should add callback' do
    callback_called = false
    other_callback_called = false
    
    @listen.do_emit_sig
    
    @listen.on('other_sig') do other_callback_called = true end
    @listen.do_emit_sig
    refute callback_called
    refute other_callback_called
    
    @listen.on('sig') do callback_called = true end
    @listen.do_emit_sig
    assert callback_called
    refute other_callback_called

    callback_called = false
    @listen.do_emit_sig
    assert callback_called
    refute other_callback_called
  end

  test 'it should giv args' do    
    args_given = nil
    @listen.on('sig') do |*args| args_given = args end
    @listen.do_emit_sig
    assert_equal [], args_given
    @listen.do_emit_sig(1, 2, 3)
    assert_equal [1, 2, 3], args_given
  end

  test 'it should remove callback 1' do
    callback_called = false
    @listen.on('sig') do callback_called = true end
    @listen.off(self, 'sig')
    @listen.do_emit_sig
    refute callback_called
  end

  test 'it should not remove callback 1' do
    callback_called = false
    @listen.on('sig') do callback_called = true end
    @listen.off(self, 'other_sig')
    @listen.do_emit_sig
    assert callback_called
  end

  test 'it should remove callback 2' do
    callback_called = false
    callback_id = @listen.on('sig') do callback_called = true end    
    @listen.off( callback_id )
    @listen.do_emit_sig
    refute callback_called
  end

  test 'it should not remove callback 2' do
    callback1_called = callback2_called = false
    callback_id_1 = @listen.on('sig') do callback1_called = true end
    callback_id_2 = @listen.on('sig') do callback2_called = true end
    @listen.off( callback_id_1 )
    @listen.do_emit_sig
    refute callback1_called
    assert callback2_called
  end

  test "it should raise we call emit" do
    assert_raises NoMethodError do
      @listen.emit('raise')
    end
  end
end
