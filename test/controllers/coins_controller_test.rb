require 'test_helper'

class CoinsControllerTest < ActionController::TestCase
  setup do
    @coin = coins(:btc)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:coins)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create coin" do
    assert_difference('Coin.count') do
      post :create, coin: { algo: @coin.algo, bitcointalk_url: @coin.bitcointalk_url, block_confirmation: @coin.block_confirmation, code: @coin.code, difficulty_retarget: @coin.difficulty_retarget, name: @coin.name, rpc_url: @coin.rpc_url, second_per_block: @coin.second_per_block, transaction_confirmation: @coin.transaction_confirmation, website: @coin.website }
    end

    assert_redirected_to coin_path(assigns(:coin))
  end

  test "should show coin" do
    get :show, id: @coin
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @coin
    assert_response :success
  end

  test "should update coin" do
    patch :update, id: @coin, coin: { algo: @coin.algo, bitcointalk_url: @coin.bitcointalk_url, block_confirmation: @coin.block_confirmation, code: @coin.code, difficulty_retarget: @coin.difficulty_retarget, name: @coin.name, rpc_url: @coin.rpc_url, second_per_block: @coin.second_per_block, transaction_confirmation: @coin.transaction_confirmation, website: @coin.website }
    assert_redirected_to coin_path(assigns(:coin))
  end

  test "should destroy coin" do
    assert_difference('Coin.count', -1) do
      delete :destroy, id: @coin
    end

    assert_redirected_to coins_path
  end
end
