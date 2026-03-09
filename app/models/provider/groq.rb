class Provider::Groq < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Groq::Error
  Error = Class.new(Provider::Error)

  # Models available on Groq's fast inference API (as of March 2026)
  MODELS = %w[llama-3.1-8b-instant llama-3.3-70b-versatile]

  def initialize(access_token)
    @client = ::OpenAI::Client.new(
      access_token: access_token,
      uri_base: "https://api.groq.com/openai/v1"
    )
  end

  def supports_model?(model)
    true
  end

  def auto_categorize(transactions: [], user_categories: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      AutoCategorizer.new(
        client,
        transactions: transactions,
        user_categories: user_categories
      ).auto_categorize
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-detect merchants. Max is 25 per request." if transactions.size > 25

      AutoMerchantDetector.new(
        client,
        transactions: transactions,
        user_merchants: user_merchants
      ).auto_detect_merchants
    end
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    with_provider_response do
      chat_config = ChatConfig.new(
        functions: functions,
        function_results: function_results,
        instructions: instructions
      )

      collected_chunks = []

      if streamer.present?
        # Streaming via Chat Completions SSE
        stream_proc = proc do |chunk, _bytesize|
          parsed_chunk = ChatStreamParser.new(chunk).parsed
          unless parsed_chunk.nil?
            streamer.call(parsed_chunk)
            collected_chunks << parsed_chunk
          end
        end

        client.chat(parameters: {
          model: model,
          messages: chat_config.build_messages(prompt),
          tools: chat_config.tools.presence,
          stream: stream_proc
        }.compact)

        # Reconstruct the full text from streamed deltas
        full_text = collected_chunks
          .select { |c| c.type == "output_text" }
          .map(&:data)
          .join

        ChatResponse.new(
          id: nil,
          model: model,
          messages: [ ChatMessage.new(id: nil, output_text: full_text) ],
          function_requests: []
        )
      else
        raw_response = client.chat(parameters: {
          model: model,
          messages: chat_config.build_messages(prompt),
          tools: chat_config.tools.presence
        }.compact)

        ChatParser.new(raw_response).parsed
      end
    end
  end

  private
    attr_reader :client

    ChatResponse = Provider::LlmConcept::ChatResponse
    ChatMessage  = Provider::LlmConcept::ChatMessage
end
