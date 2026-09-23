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

module Scripts
  class SetAttributesService < ::BaseServices::SetAttributes
    def set_attributes(params)
      set_selected_projects!(params)
      set_selected_events!(params)

      super
    end

    private

    def set_selected_events!(params)
      events = params.delete(:events) || []
      model.event_names = events.compact_blank
    end

    def set_selected_projects!(params)
      option = params.delete(:project_ids)
      selected = params.delete(:selected_project_ids)

      return if option.nil? && selected.nil?

      assign_selected_projects(option, selected)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      Rails.logger.error { "Failed to set project association on script: #{e}" }
      model.errors.add :project_ids, :invalid
    end

    def assign_selected_projects(option, selected)
      if option == "all"
        model.all_projects = true
      else
        model.all_projects = false
        model.project_ids = selected || []
      end
    end
  end
end
