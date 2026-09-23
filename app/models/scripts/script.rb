# frozen_string_literal: true

module Scripts
  class Script < ApplicationRecord
    belongs_to :creator, class_name: "User"
    belongs_to :last_modified_by_user, class_name: "User"
    has_many :events, foreign_key: :scripts_script_id, class_name: "Scripts::Event", dependent: :delete_all,
                      inverse_of: :script
    has_many :script_projects, foreign_key: :scripts_script_id, class_name: "Scripts::Project", dependent: :delete_all,
                               inverse_of: :script
    has_many :projects, through: :script_projects

    validates :name, presence: true, uniqueness: { case_sensitive: false }
    validates :text, presence: true
    validates :run_as, inclusion: { in: %w[current_user system_user] }

    def self.enabled
      where(enabled: true)
    end

    def self.with_event_name(event_name)
      enabled
        .joins(:events)
        .where("#{::Scripts::Event.table_name}.name" => event_name)
    end

    def self.new_default
      new all_projects: true, enabled: false, run_as: "current_user"
    end

    def all_projects?
      !!all_projects
    end

    def enabled_for_project?(project_id)
      all_projects? || projects.exists?(project_id)
    end

    def enabled?
      !!enabled
    end

    def event_names
      events.pluck(:name)
    end

    def event_names=(names)
      self.events = names.map { |name| events.build(name:) }
    end
  end
end
