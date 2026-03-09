class Provider::Groq::ChatStreamParser
  Error = Class.new(StandardError)

  def initialize(object)
    @object = object
  end

  # The ruby-openai gem yields raw Hash chunks from the SSE stream.
  # For chat completions, a delta chunk looks like:
  #   { "choices" => [{ "delta" => { "content" => "..." } }] }
  # A finish chunk has finish_reason set.
  def parsed
    return nil unless object.is_a?(Hash)

    choices = object.dig("choices") || []
    return nil if choices.empty?

    choice = choices.first
    delta  = choice.dig("delta") || {}
    finish = choice.dig("finish_reason")

    if delta["content"].present?
      Chunk.new(type: "output_text", data: delta["content"])
    elsif finish.present?
      # Signal end-of-stream; groq.rb handles assembly from collected deltas
      Chunk.new(type: "finish", data: finish)
    end
  end

  private
    attr_reader :object

    Chunk = Provider::LlmConcept::ChatStreamChunk
end
