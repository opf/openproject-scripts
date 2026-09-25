# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

class CreateScriptsTables < ActiveRecord::Migration[8.1]
  def change
    create_scripts_scripts
    create_scripts_events
    create_scripts_projects
  end

  private

  def create_scripts_scripts
    create_table :scripts_scripts do |t|
      t.string :name
      t.text :description
      t.text :text
      t.boolean :enabled, null: false, default: false
      t.boolean :all_projects, null: false, default: false
      t.string :run_as, null: false, default: "current_user"
      t.references :creator, foreign_key: { to_table: :users }, null: false
      t.references :last_modified_by_user, foreign_key: { to_table: :users }, null: false
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end
    add_index :scripts_scripts, "LOWER(name)", unique: true, name: "index_scripts_scripts_on_LOWER_name"
  end

  # Pure join tables, mirroring Webhooks::Event/Webhooks::Project, which are
  # also timestamp-less.
  def create_scripts_events
    create_table :scripts_events do |t| # rubocop:disable Rails/CreateTableWithTimestamps
      t.string :name
      t.references :scripts_script, foreign_key: true
    end
    add_index :scripts_events, %i[scripts_script_id name]
  end

  def create_scripts_projects
    create_table :scripts_projects do |t| # rubocop:disable Rails/CreateTableWithTimestamps
      t.references :project, foreign_key: true
      t.references :scripts_script, foreign_key: true
    end
    add_index :scripts_projects,
              %i[project_id scripts_script_id],
              unique: true,
              name: "index_scripts_projects_on_project_and_script"
  end
end
