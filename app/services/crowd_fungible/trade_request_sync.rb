# frozen_string_literal: true

module CrowdFungible
  class TradeRequestSync
    def initialize(trade_request)
      @trade_request = trade_request
    end

    def call(run: nil)
      run ||= load_run
      return trade_request unless run

      state = Rubot::HashUtils.symbolize(run.state || {})
      approval = run.approvals.last
      final_output = Rubot::HashUtils.symbolize(run.output || {})

      normalized_request = state.dig(:normalized_request, :normalized_request)

      trade_request.update!(
        rubot_run_id: run.id,
        status: derive_status(run, state, final_output, approval),
        normalized_request: normalized_request,
        account_summary: state[:lookup_account],
        quote_summary: state[:lookup_quote],
        policy_result: state[:evaluate_trade_policy],
        recommendation: state[:review_request],
        execution_result: state[:execute_order],
        approval_result: normalize_approval(approval),
        final_output: final_output.presence || state[:finalize_result],
        error_message: run.error&.dig(:message)
      )

      trade_request
    end

    private

    attr_reader :trade_request

    def load_run
      return if trade_request.rubot_run_id.blank?

      Rubot.store.find_run(trade_request.rubot_run_id)
    end

    def derive_status(run, state, final_output, approval)
      return "queued_for_approval" if run.waiting_for_approval?

      disposition = final_output[:final_disposition] || state.dig(:finalize_result, :final_disposition)
      return "executed" if disposition == "executed"
      return "rejected" if disposition == "rejected"

      if run.failed?
        return "rejected" if approval&.status == :rejected
        return "rejected" if run.error&.dig(:type) == "changes_requested"

        "failed"
      else
        "submitted"
      end
    end

    def normalize_approval(approval)
      return if approval.nil?

      {
        step_name: approval.step_name,
        status: approval.status.to_s,
        role_requirement: approval.role_requirement,
        reason: approval.reason,
        decision_payload: approval.decision_payload
      }
    end
  end
end
