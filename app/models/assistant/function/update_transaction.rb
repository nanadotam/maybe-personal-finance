class Assistant::Function::UpdateTransaction < Assistant::Function
  class << self
    def name
      "update_transaction"
    end

    def description
      "Update an existing transaction. Find it first with get_transactions. Confirm before calling."
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: %w[original_name date account_name],
      properties: {
        original_name: { type: "string", description: "Current transaction name" },
        date: { type: "string", description: "YYYY-MM-DD" },
        account_name: { type: "string", enum: family_account_names },
        new_name: { type: "string" },
        amount: { type: "string", description: "Positive number" },
        nature: { type: "string", enum: %w[expense income] },
        category_name: { type: "string", enum: family_category_names },
        notes: { type: "string" }
      }
    )
  end

  def call(params = {})
    entry = find_entry(params)
    updates = build_updates(params)

    if updates.empty?
      return { success: false, error: "No updates provided" }
    end

    if entry.update(updates)
      entry.sync_account_later
      txn = entry.transaction

      {
        success: true,
        transaction: {
          name: entry.name,
          amount: entry.amount_money.abs.format,
          nature: entry.amount.negative? ? "income" : "expense",
          date: entry.date,
          account: entry.account.name,
          category: txn.category&.name
        }
      }
    else
      { success: false, error: entry.errors.full_messages.join(", ") }
    end
  end

  private
    def find_entry(params)
      account = family.accounts.visible.find_by!(name: params["account_name"])
      entry = account.entries.where(date: Date.parse(params["date"]), name: params["original_name"])
                     .where(entryable_type: "Transaction").first

      raise "Transaction '#{params['original_name']}' not found on #{params['date']} in #{params['account_name']}" unless entry
      entry
    end

    def build_updates(params)
      updates = {}
      updates[:name] = params["new_name"] if params["new_name"].present?
      updates[:notes] = params["notes"] if params.key?("notes")

      if params["amount"].present?
        amount = params["amount"].to_f
        updates[:amount] = params["nature"] == "income" ? -amount.abs : amount.abs
      end

      if params["category_name"].present?
        category = resolve_category(params["category_name"])
        updates[:entryable_attributes] = { id: nil, category_id: category&.id }
      end

      updates
    end

    def resolve_category(category_name)
      return nil if category_name == "Uncategorized"
      family.categories.find_by(name: category_name)
    end
end
