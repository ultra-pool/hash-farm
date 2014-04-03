require 'test_helper'

class PayoutsControllerTest < ActionController::TestCase
  setup do
    @payout = payouts(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:payouts)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create payout" do
    assert_difference('Payout.count') do
      post :create, payout: { our_fees: @payout.our_fees, transaction_id: @payout.transaction_id, users_amount: @payout.users_amount }
    end

    assert_redirected_to payout_path(assigns(:payout))
  end

  test "should show payout" do
    get :show, id: @payout
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @payout
    assert_response :success
  end

  test "should update payout" do
    patch :update, id: @payout, payout: { our_fees: @payout.our_fees, transaction_id: @payout.transaction_id, users_amount: @payout.users_amount }
    assert_redirected_to payout_path(assigns(:payout))
  end

  test "should destroy payout" do
    assert_difference('Payout.count', -1) do
      delete :destroy, id: @payout
    end

    assert_redirected_to payouts_path
  end
end
