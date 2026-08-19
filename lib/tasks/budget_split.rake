namespace :budget_split do
  desc "Seed the personal GHS tithe/needs/wants/savings budget split for the first family"
  task seed: :environment do
    family = Family.first
    raise "No family found — sign up / onboard a user first" unless family

    rule = BudgetSplitRule.seed_ghs_default_for(family)

    puts "✅ Seeded BudgetSplitRule for #{family.name} (id=#{rule.id})"
    puts "   Target split — Tithe #{rule.tithe_percent}% / Needs #{rule.needs_percent}% / Wants #{rule.wants_percent}% / Savings #{rule.savings_percent}%"
    rule.budget_split_allocations.order(:bucket, :name).each do |a|
      puts "   - #{a.name.ljust(20)} #{a.bucket.ljust(8)} #{a.percent}%"
    end
  end

  desc "Seed FAKE demo transactions this month, modeled on real spend patterns, for visualizing the /portfolio dashboard. Run budget_split:seed first."
  task demo_data: :environment do
    family = Family.first
    raise "No family found — sign up first" unless family

    rule = family.budget_split_rule
    raise "No BudgetSplitRule found — run `rake budget_split:seed` first" unless rule

    account = ->(name) { family.accounts.find_by!(name: name) }
    category = ->(name) { family.categories.find_by!(name: name) }

    ecobank_current = account.("EcoBank Current")
    ecobank_savings = account.("EcoBank Savings")
    databank = account.("Databank")
    zenith = account.("Zenith")
    achieve = account.("Achieve")

    tithe_cat = category.("Tithe")
    offertory_cat = category.("Offertory")
    airtime_cat = category.("Airtime & Data")
    subs_cat = category.("Subscriptions")
    enjoyment_cat = category.("Enjoyment")
    misc_cat = category.("Miscellaneous")

    today = Date.current

    def create_transaction!(account, amount, name, category, date)
      account.entries.create!(
        entryable: Transaction.new(category: category),
        amount: amount,
        name: name,
        currency: account.currency,
        date: date
      )
    end

    def create_transfer!(family, from_account, to_account, amount, date)
      transfer = Transfer::Creator.new(
        family: family,
        source_account_id: from_account.id,
        destination_account_id: to_account.id,
        date: date,
        amount: amount
      ).create

      raise "Transfer failed: #{transfer.errors.full_messages.join(', ')}" unless transfer.persisted?
    end

    # -- Real-pattern spend on EcoBank Current (merchants from your actual statements) --
    real_pattern_spend = [
      [ "Papaye Haatso Take Out", 160.00 ],
      [ "Akorno Services — food", 34.00 ],
      [ "Starbites East Legon", 170.00 ],
      [ "MTN MoMo transfer — food", 60.00 ],
      [ "Silverbird Accra Mall", 110.00 ]
    ]
    real_pattern_spend.each_with_index do |(name, amount), i|
      create_transaction!(ecobank_current, amount, "[DEMO] #{name}", nil, today - (real_pattern_spend.size - i).days)
    end

    # -- Category-linked recurring commitments --
    create_transaction!(ecobank_current, 750.00, "[DEMO] Tithe — God", tithe_cat, today - 18.days)
    create_transaction!(ecobank_current, 40.00,  "[DEMO] PCG Agbogba offering", offertory_cat, today - 14.days)
    create_transaction!(ecobank_current, 50.00,  "[DEMO] MTN Airtime top-up", airtime_cat, today - 10.days)
    create_transaction!(ecobank_current, 264.00, "[DEMO] Claude AI Subscription", subs_cat, today - 9.days)
    create_transaction!(ecobank_current, 37.00,  "[DEMO] Spotify", subs_cat, today - 9.days)
    create_transaction!(ecobank_current, 43.00,  "[DEMO] YouTube Premium", subs_cat, today - 9.days)
    create_transaction!(ecobank_current, 300.00, "[DEMO] Enjoyment — weekend", enjoyment_cat, today - 6.days)
    create_transaction!(ecobank_current, 90.00,  "[DEMO] Misc — untracked", misc_cat, today - 3.days)

    # -- Internal transfers into savings/investment accounts (this is what "actual" tracks for the savings bucket) --
    create_transfer!(family, ecobank_current, databank, 1250.00, today - 15.days)
    create_transfer!(family, ecobank_current, zenith,   625.00,  today - 15.days)
    create_transfer!(family, ecobank_current, achieve,  625.00,  today - 15.days)
    create_transfer!(family, ecobank_current, ecobank_savings, 1250.00, today - 5.days)

    puts "✅ Seeded demo transactions for #{family.name}. Visit /portfolio to view."
    puts "   Spend transactions are prefixed '[DEMO]'. Transfers use Transfer::Creator's own naming."
    puts "   To wipe all demo data, run: rake budget_split:demo_data_clear"
  end

  desc "Delete all entries on the 5 budget-split accounts (Databank/Zenith/Achieve/EcoBank Savings/EcoBank Current) — clears demo data without deleting the accounts themselves"
  task demo_data_clear: :environment do
    family = Family.first
    raise "No family found" unless family

    account_names = [ "Databank", "Zenith", "Achieve", "EcoBank Savings", "EcoBank Current" ]
    accounts = family.accounts.where(name: account_names)

    count = accounts.sum { |a| a.entries.count }
    accounts.each { |a| a.entries.destroy_all }

    puts "✅ Cleared #{count} entries across #{accounts.count} accounts."
  end
end
