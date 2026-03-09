class Chat < ApplicationRecord
  include Debuggable

  belongs_to :user

  has_one :viewer, class_name: "User", foreign_key: :last_viewed_chat_id, dependent: :nullify # "Last chat user has viewed"
  has_many :messages, dependent: :destroy

  validates :title, presence: true

  scope :ordered, -> { order(created_at: :desc) }

  class << self
    def start!(prompt, model:)
      create!(
        title: generate_title(prompt),
        messages: [ UserMessage.new(content: prompt, ai_model: model) ]
      )
    end

    def generate_title(prompt)
      prompt.first(80)
    end
  end

  def needs_assistant_response?
    conversation_messages.ordered.last.role != "assistant"
  end

  def retry_last_message!
    update!(error: nil)

    last_message = conversation_messages.ordered.last

    if last_message.present? && last_message.role == "user"

      ask_assistant_later(last_message)
    end
  end

  def update_latest_response!(provider_response_id)
    update!(latest_assistant_response_id: provider_response_id)
  end

  def add_error(e)
    update! error: e.to_json
    broadcast_append target: "messages", partial: "chats/error", locals: { chat: self }
  end

  def friendly_error_message
    return "Something went wrong. Please try again." if error.blank?

    # The error may be double-JSON-encoded, so parse until we get a non-string
    message = extract_error_message(error)

    case message
    when /rate limit|cool down/i
      message
    when /too many requests/i
      message
    when /authentication|api key/i
      message
    when /model.*not found/i
      message
    when /failed to call a function|failed_generation/i
      "The AI had trouble processing your request. Please try rephrasing your message."
    else
      "Something went wrong. Please try again."
    end
  end

  def clear_error
    update! error: nil
    broadcast_remove target: "chat-error"
  end

  def assistant
    @assistant ||= Assistant.for_chat(self)
  end

  def ask_assistant_later(message)
    clear_error
    AssistantResponseJob.perform_later(message)
  end

  def ask_assistant(message)
    assistant.respond_to(message)
  end

  def conversation_messages
    if debug_mode?
      messages
    else
      messages.where(type: [ "UserMessage", "AssistantMessage" ])
    end
  end

  private
    def extract_error_message(raw)
      # Unwrap nested JSON encoding (e.g. to_json on an object that was already serialized)
      value = raw
      3.times do
        parsed = JSON.parse(value) rescue break
        if parsed.is_a?(Hash)
          return parsed["message"] || parsed["error"] || value
        elsif parsed.is_a?(String)
          value = parsed
        else
          break
        end
      end
      value
    end
end
