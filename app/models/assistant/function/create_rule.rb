class Assistant::Function::CreateRule < Assistant::Function
  class << self
    def name
      "create_rule"
    end

    def description
      "Create an auto-categorization rule for future transactions. Confirm before calling."
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: %w[condition_field condition_operator condition_value action_type action_value],
      properties: {
        name: { type: "string" },
        condition_field: { type: "string", enum: %w[transaction_name transaction_amount] },
        condition_operator: { type: "string", enum: %w[contains equals starts_with ends_with greater_than less_than] },
        condition_value: { type: "string" },
        action_type: { type: "string", enum: %w[set_category set_merchant set_tags] },
        action_value: { type: "string", description: "Category, merchant, or comma-separated tags" },
        apply_to_existing: { type: "boolean" }
      }
    )
  end

  def call(params = {})
    rule = family.rules.new(
      active: true,
      effective_date: Date.current
    )

    # Build condition
    condition = rule.conditions.build(
      condition_type: params["condition_field"],
      operator: map_operator(params["condition_operator"]),
      value: params["condition_value"]
    )

    # Build action
    action_config = build_action(params["action_type"], params["action_value"])
    action = rule.actions.build(action_config)

    if rule.save
      rule.apply if params["apply_to_existing"]

      {
        success: true,
        rule: {
          id: rule.id,
          condition: "#{params['condition_field']} #{params['condition_operator']} '#{params['condition_value']}'",
          action: "#{params['action_type']}: #{params['action_value']}",
          applied_to_existing: params["apply_to_existing"] || false
        }
      }
    else
      { success: false, error: rule.errors.full_messages.join(", ") }
    end
  end

  private
    def map_operator(operator)
      case operator
      when "contains" then "contains"
      when "equals" then "="
      when "starts_with" then "starts_with"
      when "ends_with" then "ends_with"
      when "greater_than" then ">"
      when "less_than" then "<"
      else operator
      end
    end

    def build_action(action_type, action_value)
      case action_type
      when "set_category"
        category = family.categories.find_by(name: action_value)
        { action_type: "set_transaction_category", value: category&.id }
      when "set_merchant"
        merchant = family.merchants.find_by(name: action_value) ||
                   family.merchants.create!(name: action_value, type: "FamilyMerchant")
        { action_type: "set_transaction_merchant", value: merchant.id }
      when "set_tags"
        tag_names = action_value.split(",").map(&:strip)
        tag_ids = tag_names.map do |name|
          family.tags.find_or_create_by!(name: name).id
        end
        { action_type: "set_transaction_tags", value: tag_ids.join(",") }
      end
    end
end
