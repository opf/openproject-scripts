# frozen_string_literal: true

module Scripts
  class Event < ApplicationRecord
    belongs_to :script, foreign_key: :scripts_script_id, class_name: "Scripts::Script", inverse_of: :events

    validates :name, presence: true
  end
end
