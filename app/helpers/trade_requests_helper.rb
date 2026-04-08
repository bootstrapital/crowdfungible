# frozen_string_literal: true

module TradeRequestsHelper
  def trade_request_status_label(status)
    status.to_s.tr("_", " ").capitalize
  end

  def trade_request_status_class(status)
    case status.to_s
    when "executed" then "status-pill status-pill--good"
    when "queued_for_approval" then "status-pill status-pill--warn"
    when "rejected", "failed" then "status-pill status-pill--bad"
    else "status-pill"
    end
  end

  def pretty_data(data)
    JSON.pretty_generate(data || {})
  end

  def format_money(value)
    return "n/a" if value.blank?

    number_to_currency(value)
  end
end
