class CreateTradeRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :trade_requests do |t|
      t.text :request_text
      t.string :side
      t.string :symbol
      t.decimal :quantity, precision: 12, scale: 4
      t.decimal :notional_usd, precision: 12, scale: 2
      t.string :order_type, null: false, default: "market"
      t.string :submitted_by
      t.string :status, null: false, default: "submitted"
      t.string :rubot_run_id
      t.json :normalized_request
      t.json :account_summary
      t.json :quote_summary
      t.json :policy_result
      t.json :recommendation
      t.json :execution_result
      t.json :approval_result
      t.json :final_output
      t.text :error_message

      t.timestamps
    end

    add_index :trade_requests, :status
    add_index :trade_requests, :rubot_run_id
  end
end
