# frozen_string_literal: true

class TradeRequest < ApplicationRecord
  STATUSES = %w[submitted executed queued_for_approval rejected failed].freeze
  ORDER_TYPES = %w[market].freeze
  SIDES = %w[buy sell].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :order_type, inclusion: { in: ORDER_TYPES }
  validates :side, inclusion: { in: SIDES }, allow_blank: true

  scope :recent_first, -> { order(created_at: :desc) }

  def rubot_admin_url
    return if rubot_run_id.blank?

    "/rubot/admin/runs/#{rubot_run_id}"
  end
end
