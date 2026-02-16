require "rails_helper"
require "rake"

RSpec.describe "master_data:sync" do
  before(:all) do
    Rails.application.load_tasks
  end

  before do
    Rake::Task["master_data:sync"].reenable
  end

  let(:master_data_dir) { Rails.root.join("config", "master_data") }

  shared_examples "master data sync" do |key, model_class, extra_fields|
    let(:yaml_path) { master_data_dir.join("#{key}.yml") }
    let(:yaml_data) { YAML.load_file(yaml_path) }
    let(:entries) { yaml_data[key.to_s] }

    describe "#{model_class.name} sync" do
      context "when DB has no records" do
        it "creates records from YAML" do
          expect {
            Rake::Task["master_data:sync"].invoke
          }.to change(model_class, :count).by(entries.size)

          entries.each do |entry|
            record = model_class.find_by(name: entry["name"])
            expect(record).to be_present
            expect(record.description).to eq(entry["description"])
            extra_fields.each do |field|
              expect(record.send(field)).to eq(entry[field.to_s])
            end
          end
        end
      end

      context "when a record exists with different description" do
        before do
          model_class.create!(
            name: entries.first["name"],
            description: "古い説明文",
            **extra_fields.to_h { |f| [ f, entries.first[f.to_s] ] }.compact
          )
        end

        it "updates the existing record" do
          Rake::Task["master_data:sync"].invoke

          record = model_class.find_by(name: entries.first["name"])
          expect(record.description).to eq(entries.first["description"])
        end
      end

      context "when records already match YAML" do
        before do
          # Run sync once to populate
          Rake::Task["master_data:sync"].invoke
          Rake::Task["master_data:sync"].reenable
        end

        it "does not update records" do
          timestamps_before = model_class.pluck(:id, :updated_at).to_h

          Rake::Task["master_data:sync"].invoke

          timestamps_after = model_class.pluck(:id, :updated_at).to_h
          expect(timestamps_after).to eq(timestamps_before)
        end
      end
    end
  end

  it_behaves_like "master data sync", :batting_styles, BattingStyle, []
  it_behaves_like "master data sync", :pitching_styles, PitchingStyle, []
  it_behaves_like "master data sync", :batting_skills, BattingSkill, [ :skill_type ]
  it_behaves_like "master data sync", :pitching_skills, PitchingSkill, [ :skill_type ]
  it_behaves_like "master data sync", :player_types, PlayerType, [ :category ]
end
