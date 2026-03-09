class Assistant::Function::GetTransactions < Assistant::Function
  include Pagy::Backend

  PAGE_SIZES = { "summary" => 5, "standard" => 15, "detailed" => 30 }.freeze

  class << self
    def name
      "get_transactions"
    end

    def description
      "Search and filter user transactions. Paginated. For large time periods, use get_income_statement instead."
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [ "order", "page" ],
      properties: {
        page: { type: "integer" },
        order: { enum: %w[asc desc] },
        detail_level: { type: "string", enum: %w[summary standard detailed] },
        search: { type: "string", description: "Search by name" },
        amount: { type: "string" },
        amount_operator: { type: "string", enum: %w[equal less greater] },
        start_date: { type: "string", description: "YYYY-MM-DD" },
        end_date: { type: "string", description: "YYYY-MM-DD" },
        accounts: { type: "array", items: { enum: family_account_names } },
        categories: { type: "array", items: { enum: family_category_names } },
        merchants: { type: "array", items: { enum: family_merchant_names } },
        tags: { type: "array", items: { enum: family_tag_names } }
      }
    )
  end

  def call(params = {})
    level = params.fetch("detail_level", "summary")
    page_size = PAGE_SIZES.fetch(level, PAGE_SIZES["summary"])
    search_params = params.except("order", "page", "detail_level")

    search = Transaction::Search.new(family, filters: search_params)
    transactions_query = search.transactions_scope
    pagy_query = params["order"] == "asc" ? transactions_query.chronological : transactions_query.reverse_chronological

    pagy, paginated_transactions = pagy(
      pagy_query.includes(
        { entry: :account },
        :category, :merchant, :tags,
        transfer_as_outflow: { inflow_transaction: { entry: :account } },
        transfer_as_inflow: { outflow_transaction: { entry: :account } }
      ),
      page: params["page"] || 1,
      limit: page_size
    )

    totals = search.totals

    normalized_transactions = paginated_transactions.map do |txn|
      entry = txn.entry
      {
        date: entry.date,
        formatted_amount: entry.amount_money.abs.format,
        classification: entry.amount < 0 ? "income" : "expense",
        account: entry.account.name,
        category: txn.category&.name,
        merchant: txn.merchant&.name
      }
    end

    {
      transactions: normalized_transactions,
      total_results: pagy.count,
      page: pagy.page,
      page_size: page_size,
      total_pages: pagy.pages,
      total_income: totals.income_money.format,
      total_expenses: totals.expense_money.format
    }
  end
end
