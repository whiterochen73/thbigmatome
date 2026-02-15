namespace :master_data do
  def master_data_dir
    Rails.root.join("config", "master_data")
  end

  def master_data_models
    {
      batting_styles: { model: BattingStyle, order: :id, fields: %i[name description] },
      pitching_styles: { model: PitchingStyle, order: :id, fields: %i[name description] },
      batting_skills: { model: BattingSkill, order: :id, fields: %i[name description skill_type] },
      pitching_skills: { model: PitchingSkill, order: :id, fields: %i[name description skill_type] },
      player_types: { model: PlayerType, order: :id, fields: %i[name description] }
    }
  end

  desc "Export master data from DB to YAML files (config/master_data/)"
  task export: :environment do
    FileUtils.mkdir_p(master_data_dir)

    master_data_models.each do |key, config|
      records = config[:model].order(config[:order]).map do |record|
        entry = { "key" => record.name }
        config[:fields].each do |field|
          entry[field.to_s] = record.send(field)
        end
        entry
      end

      file_path = master_data_dir.join("#{key}.yml")
      File.write(file_path, { key.to_s => records }.to_yaml)
      puts "Exported #{records.size} #{key} to #{file_path}"
    end
  end

  desc "Sync master data from YAML files to DB (upsert by name, no deletes)"
  task sync: :environment do
    master_data_models.each do |key, config|
      file_path = master_data_dir.join("#{key}.yml")
      unless File.exist?(file_path)
        puts "SKIP: #{file_path} not found"
        next
      end

      data = YAML.load_file(file_path)
      entries = data[key.to_s] || []

      entries.each do |entry|
        record = config[:model].find_or_initialize_by(name: entry["name"])
        is_new = record.new_record?
        attrs = config[:fields].each_with_object({}) do |field, hash|
          hash[field] = entry[field.to_s] if entry.key?(field.to_s)
        end
        record.assign_attributes(attrs)
        if record.new_record? || record.changed?
          record.save!
          puts "#{is_new ? 'Created' : 'Updated'} #{key}: #{entry['name']}"
        end
      end

      puts "Synced #{entries.size} #{key}"
    end
  end
end
