# -*- encoding : utf-8 -*-

require 'test_helper'
require 'ostruct'

require "pool/worker_connection"

class WorkerConnectionTest < ActiveSupport::TestCase

  setup do
  end

  teardown do
  end

  test 'it should initialize' do
    worker = WorkerConnection
  end
end