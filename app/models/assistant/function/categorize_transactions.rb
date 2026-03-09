class Assistant::Function::CategorizeTransactions < Assistant::Function
  class << self
    def name
      "categorize_transactions"
    end

    def description
      "Set category on one or more transactions. Find them first with get_transactions."
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: %w[category_name transactions],
      properties: {
        category_name: { type: "string", enum: family_category_names },
        transactions: {
          type: "array",
          items: {
            type: "object",
            properties: {
              name: { type: "string" },
              date: { type: "string" },
              account_name: { type: "string" }
            },
            required: %w[name date account_name]
          }
        }
      }
    )
  end

  def call(params = {})
    category = resolve_category(params["category_name"])
    results = []

    params["transactions"].each do |txn_ref|
      account = family.accounts.visible.find_by(name: txn_ref["account_name"])
      next results << { name: txn_ref["name"], status: "error", error: "Account not found" } unless account

      entry = account.entries.where(date: Date.parse(txn_ref["date"]), name: txn_ref["name"])
                     .where(entryable_type: "Transaction").first
      next results << { name: txn_ref["name"], status: "error", error: "Transaction not found" } unless entry

      entry.transaction.update!(category: category)
      results << { name: entry.name, status: "updated", category: category&.name || "Uncategorized" }
    end

    { success: true, category: params["category_name"], results: results }
  end

  private
    def resolve_category(name)
      return nil if name == "Uncategorized"
      family.categories.find_by(name: name)
    end
end
