class Assistant::Function::TagTransactions < Assistant::Function
  class << self
    def name
      "tag_transactions"
    end

    def description
      "Add or remove tags on transactions. Find them first with get_transactions."
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    properties = {
      action: { type: "string", enum: %w[add remove] },
      tag_name: { type: "string" },
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

    # Add enum for existing tags if any exist
    if family_tag_names.any?
      properties[:tag_name][:enum] = family_tag_names
    end

    build_schema(required: %w[action tag_name transactions], properties: properties)
  end

  def call(params = {})
    tag = find_or_create_tag(params["tag_name"], params["action"])
    results = []

    params["transactions"].each do |txn_ref|
      account = family.accounts.visible.find_by(name: txn_ref["account_name"])
      next results << { name: txn_ref["name"], status: "error", error: "Account not found" } unless account

      entry = account.entries.where(date: Date.parse(txn_ref["date"]), name: txn_ref["name"])
                     .where(entryable_type: "Transaction").first
      next results << { name: txn_ref["name"], status: "error", error: "Transaction not found" } unless entry

      txn = entry.transaction
      if params["action"] == "add"
        txn.tags << tag unless txn.tags.include?(tag)
        results << { name: entry.name, status: "tagged" }
      else
        txn.tags.delete(tag)
        results << { name: entry.name, status: "untagged" }
      end
    end

    { success: true, tag: params["tag_name"], action: params["action"], results: results }
  end

  private
    def find_or_create_tag(tag_name, action)
      tag = family.tags.find_by(name: tag_name)
      if tag.nil? && action == "add"
        tag = family.tags.create!(name: tag_name)
      elsif tag.nil?
        raise "Tag '#{tag_name}' not found"
      end
      tag
    end
end
