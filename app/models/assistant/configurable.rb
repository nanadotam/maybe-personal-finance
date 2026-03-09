module Assistant::Configurable
  extend ActiveSupport::Concern

  class_methods do
    def config_for(chat)
      preferred_currency = Money::Currency.new(chat.user.family.currency)
      preferred_date_format = chat.user.family.date_format

      {
        instructions: default_instructions(preferred_currency, preferred_date_format),
        functions: default_functions
      }
    end

    private
      def default_functions
        [
          # Read functions
          Assistant::Function::GetTransactions,
          Assistant::Function::GetAccounts,
          Assistant::Function::GetBalanceSheet,
          Assistant::Function::GetIncomeStatement,
          Assistant::Function::GetSpendingTrends,
          # Write functions
          Assistant::Function::CreateTransaction,
          Assistant::Function::UpdateTransaction,
          Assistant::Function::DeleteTransaction,
          Assistant::Function::CategorizeTransactions,
          Assistant::Function::TagTransactions,
          Assistant::Function::CreateRule
        ]
      end

      def default_instructions(preferred_currency, preferred_date_format)
        <<~PROMPT
          You are a financial assistant for Maybe Finance. Be concise. Use markdown. Today: #{Date.current}

          Currency: #{preferred_currency.iso_code} (#{preferred_currency.symbol}), precision: #{preferred_currency.default_precision}, separator: "#{preferred_currency.separator}", delimiter: "#{preferred_currency.delimiter}". Date format: #{preferred_date_format}

          Rules:
          - Use functions to get data, never assume. Use detail_level "summary" by default.
          - Always use the native tool_calls mechanism. NEVER use XML tags for function calls.
          - Be brief: key numbers and insights only. Ask follow-up questions.
          - For write operations (create/update/delete), confirm with user first.
          - Don't recommend buying/selling specific investments.
        PROMPT
      end
  end
end
