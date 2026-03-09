class Assistant::Function::DeleteTransaction < Assistant::Function
  class << self
    def name
      "delete_transaction"
    end

    def description
      "Delete a transaction. Find it first with get_transactions. Confirm before calling."
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: %w[name date account_name],
      properties: {
        name: { type: "string" },
        date: { type: "string", description: "YYYY-MM-DD" },
        account_name: { type: "string", enum: family_account_names }
      }
    )
  end

  def call(params = {})
    account = family.accounts.visible.find_by!(name: params["account_name"])
    entry = account.entries.where(date: Date.parse(params["date"]), name: params["name"])
                   .where(entryable_type: "Transaction").first

    raise "Transaction '#{params['name']}' not found on #{params['date']} in #{params['account_name']}" unless entry

    deleted_info = {
      name: entry.name,
      amount: entry.amount_money.abs.format,
      date: entry.date,
      account: account.name
    }

    entry.destroy!
    entry.sync_account_later

    { success: true, deleted_transaction: deleted_info }
  end
end
