# frozen_string_literal: true

class TradeRequestsController < ApplicationController
  before_action :set_trade_request, only: :show

  def index
    @trade_requests = TradeRequest.recent_first.limit(25)
    @trade_requests.each { |trade_request| CrowdFungible::TradeRequestSync.new(trade_request).call }
  end

  def new
    @trade_request = TradeRequest.new(order_type: "market", submitted_by: "demo_user@example.com")
  end

  def create
    @trade_request = TradeRequest.create!(trade_request_attributes)

    run = CrowdFungible::TradeRequest::Operation.launch(
      payload: workflow_payload(@trade_request),
      subject: @trade_request,
      context: { submitted_via: "product_ui" },
      workflow: :trade_request
    )

    CrowdFungible::TradeRequestSync.new(@trade_request).call(run: run)
    redirect_to @trade_request
  rescue StandardError => e
    @trade_request ||= TradeRequest.new(trade_request_attributes)
    @trade_request.status = "failed"
    @trade_request.error_message = e.message
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  def show
    CrowdFungible::TradeRequestSync.new(@trade_request).call
    @run = @trade_request.rubot_run_id.present? ? Rubot.store.find_run(@trade_request.rubot_run_id) : nil
  end

  private

  def set_trade_request
    @trade_request = TradeRequest.find(params[:id])
  end

  def workflow_payload(trade_request)
    {
      request_text: trade_request.request_text,
      side: trade_request.side,
      symbol: trade_request.symbol,
      quantity: trade_request.quantity&.to_f,
      notional_usd: trade_request.notional_usd&.to_f,
      order_type: trade_request.order_type,
      submitted_by: trade_request.submitted_by
    }
  end

  def trade_request_attributes
    attrs = params.require(:trade_request).permit(:request_text, :side, :symbol, :quantity, :notional_usd, :order_type, :submitted_by).to_h
    attrs[:symbol] = attrs[:symbol].to_s.upcase.presence
    attrs[:side] = attrs[:side].presence
    attrs[:quantity] = decimal_or_nil(attrs[:quantity])
    attrs[:notional_usd] = decimal_or_nil(attrs[:notional_usd])
    attrs[:request_text] = attrs[:request_text].to_s.strip.presence
    attrs[:submitted_by] = attrs[:submitted_by].to_s.strip.presence
    attrs
  end

  def decimal_or_nil(value)
    return if value.blank?

    BigDecimal(value.to_s)
  rescue ArgumentError
    nil
  end
end
