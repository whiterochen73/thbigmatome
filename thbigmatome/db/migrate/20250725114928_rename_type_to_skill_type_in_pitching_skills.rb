class RenameTypeToSkillTypeInPitchingSkills < ActiveRecord::Migration[8.0]
  def change
    rename_column :pitching_skills, :type, :skill_type
  end
end
