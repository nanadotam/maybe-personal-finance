class Assistant::Function::CreateTransaction < Assistant::Function
  class << self
    def name
      "create_transaction"
    end

    def description
      "Create a new expense or income transaction. Confirm with user before calling."
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: %w[name amount nature],
      properties: {
        name: { type: "string", description: "Transaction name" },
        amount: { type: "string", description: "Positive number" },
        nature: { type: "string", enum: %w[expense income] },
        date: { type: "string", description: "YYYY-MM-DD, default today" },
        account_name: { type: "string", enum: family_account_names },
        category_name: { type: "string", enum: family_category_names },
        notes: { type: "string" }
      }
    )
  end

  def call(params = {})
    account = resolve_account(params["account_name"])
    category = resolve_category(params["category_name"])

    amount = params["amount"].to_f
    signed_amount = params["nature"] == "income" ? -amount.abs : amount.abs

    entry = account.entries.new(
      name: params["name"],
      date: params["date"].present? ? Date.parse(params["date"]) : Date.current,
      amount: signed_amount,
      currency: family.currency,
      notes: params["notes"],
      entryable_type: "Transaction",
      entryable_attributes: {
        category_id: category&.id
      }
    )

    if entry.save
      entry.sync_account_later

      {
        success: true,
        transaction: {
          name: entry.name,
          amount: entry.amount_money.abs.format,
          nature: params["nature"],
          date: entry.date,
          account: account.name,
          category: category&.name,
          notes: entry.notes
        }
      }
    else
      {
        success: false,
        error: entry.errors.full_messages.join(", ")
      }
    end
  end

  private
    def resolve_account(account_name)
      if account_name.present?
        family.accounts.visible.find_by!(name: account_name)
      else
        family.accounts.visible.first!
      end
    rescue ActiveRecord::RecordNotFound
      raise "Account '#{account_name}' not found"
    end

    def resolve_category(category_name)
      return nil if category_name.blank? || category_name == "Uncategorized"
      family.categories.find_by(name: category_name)
    end
end
