# frozen_string_literal: true

module Scripts
  class Project < ApplicationRecord
    belongs_to :script, foreign_key: :scripts_script_id, class_name: "Scripts::Script", inverse_of: :script_projects
    belongs_to :project, class_name: "::Project"

    validates :project, presence: true
  end
end
