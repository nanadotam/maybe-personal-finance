class Assistant::Function::GetTransactions < Assistant::Function
  include Pagy::Backend

  PAGE_SIZES = { "summary" => 5, "standard" => 15, "detailed" => 30 }.freeze

  class << self
    def name
      "get_transactions"
    end

    def description
      <<~INSTRUCTIONS
        Use this to search user's transactions by using various optional filters.

        Use detail_level to control how many transactions are returned per page:
        - "summary": 5 per page (lowest token usage)
        - "standard": 15 per page (default)
        - "detailed": 30 per page

        This function is great for things like:
        - Finding specific transactions
        - Getting basic stats about a small group of transactions

        This function is not great for:
        - Large time periods (use the get_income_statement function for this)

        Note on pagination:

        This function can be paginated.  You can expect the following properties in the response:

        - `total_pages`: The total number of pages of results
        - `page`: The current page of results
        - `page_size`: The number of results per page
        - `total_results`: The total number of results for the given filters
        - `total_income`: The total income for the given filters
        - `total_expenses`: The total expenses for the given filters

        Simple example (transactions from the last 30 days):

        ```
        get_transactions({
          page: 1,
          start_date: "#{30.days.ago.to_date}",
          end_date: "#{Date.current}"
        })
        ```

        More complex example (various filters):

        ```
        get_transactions({
          page: 1,
          search: "mcdonalds",
          accounts: ["Checking", "Savings"],
          start_date: "#{30.days.ago.to_date}",
          end_date: "#{Date.current}",
          categories: ["Restaurants"],
          merchants: ["McDonald's"],
          tags: ["Food"],
          amount: "100",
          amount_operator: "less"
        })
        ```
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [ "order", "page" ],
      properties: {
        page: {
          type: "integer",
          description: "Page number"
        },
        order: {
          enum: [ "asc", "desc" ],
          description: "Order of the transactions by date"
        },
        detail_level: {
          type: "string",
          enum: %w[summary standard detailed],
          description: "Controls how many transactions per page. Default: summary"
        },
        search: {
          type: "string",
          description: "Search for transactions by name"
        },
        amount: {
          type: "string",
          description: "Amount for transactions (must be used with amount_operator)"
        },
        amount_operator: {
          type: "string",
          description: "Operator for amount (must be used with amount)",
          enum: [ "equal", "less", "greater" ]
        },
        start_date: {
          type: "string",
          description: "Start date for transactions in YYYY-MM-DD format"
        },
        end_date: {
          type: "string",
          description: "End date for transactions in YYYY-MM-DD format"
        },
        accounts: {
          type: "array",
          description: "Filter transactions by account name",
          items: { enum: family_account_names },
          minItems: 1,
          uniqueItems: true
        },
        categories: {
          type: "array",
          description: "Filter transactions by category name",
          items: { enum: family_category_names },
          minItems: 1,
          uniqueItems: true
        },
        merchants: {
          type: "array",
          description: "Filter transactions by merchant name",
          items: { enum: family_merchant_names },
          minItems: 1,
          uniqueItems: true
        },
        tags: {
          type: "array",
          description: "Filter transactions by tag name",
          items: { enum: family_tag_names },
          minItems: 1,
          uniqueItems: true
        }
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
