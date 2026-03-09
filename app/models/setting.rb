# Dynamic settings the user can change within the app (helpful for self-hosting)
class Setting < RailsSettings::Base
  cache_prefix { "v1" }

  field :synth_api_key, type: :string, default: ENV["SYNTH_API_KEY"]
  field :exchangerate_api_key, type: :string, default: ENV["EXCHANGERATE_API_KEY"]
  field :fmp_api_key, type: :string, default: ENV["FMP_API_KEY"]

  field :groq_api_key, type: :string, default: ENV["GROQ_API_KEY"]

  field :require_invite_for_signup, type: :boolean, default: false
  field :require_email_confirmation, type: :boolean, default: ENV.fetch("REQUIRE_EMAIL_CONFIRMATION", "true") == "true"
end
