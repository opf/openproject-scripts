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
  class ScriptForm < ApplicationForm
    form do |f|
      f.text_field(
        name: :name,
        label: ::Scripts::Script.human_attribute_name(:name),
        required: true,
        input_width: :large
      )

      f.text_area(
        name: :description,
        label: ::Scripts::Script.human_attribute_name(:description),
        input_width: :large,
        rows: 2
      )

      # No `input_width:` here so the wrapper doesn't apply Primer's fixed
      # max-width classes; the inline `width: 100%` then fills the whole
      # container. The container's own width is set below via the ERB
      # wrapper in _form.html.erb.
      f.text_area(
        name: :text,
        label: ::Scripts::Script.human_attribute_name(:text),
        caption: I18n.t("scripts.form.text.description"),
        required: true,
        rows: 25,
        style: "font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; " \
               "font-size: 13px; width: 100%;"
      )

      f.check_box(
        name: :enabled,
        label: ::Scripts::Script.human_attribute_name(:enabled),
        caption: I18n.t("scripts.form.enabled.description")
      )

      f.radio_button_group(name: :execution_mode, label: I18n.t("scripts.form.execution_mode.title")) do |radios|
        radios.radio_button(
          value: "delayed_async",
          label: I18n.t("scripts.form.execution_mode.delayed_async.label"),
          caption: I18n.t("scripts.form.execution_mode.delayed_async.description"),
          checked: model.execution_mode == "delayed_async"
        )
        radios.radio_button(
          value: "immediate",
          label: I18n.t("scripts.form.execution_mode.immediate.label"),
          caption: I18n.t("scripts.form.execution_mode.immediate.description"),
          checked: model.execution_mode == "immediate"
        )
      end

      f.radio_button_group(name: :run_as, label: I18n.t("scripts.form.run_as.title")) do |radios|
        radios.radio_button(
          value: "current_user",
          label: I18n.t("scripts.form.run_as.current_user"),
          checked: model.run_as == "current_user"
        )
        radios.radio_button(
          value: "system_user",
          label: I18n.t("scripts.form.run_as.system_user"),
          checked: model.run_as == "system_user"
        )
      end

      ::OpenProject::Scripts::EventResources.available_events_map.each do |resource_label, events|
        f.check_box_group(name: :events, label: resource_label) do |group|
          events.each do |key, label|
            group.check_box(
              value: key,
              label: label,
              checked: model.event_names.include?(key),
              # Every check_box_group call above renders its own hidden [] sentinel,
              # so we don't need extra plumbing to distinguish "empty" from "unset".
              scope_name_to_model: true
            )
          end
        end
      end

      f.radio_button_group(name: :project_ids, label: I18n.t("scripts.form.project_ids.title"),
                           caption: I18n.t("scripts.form.project_ids.description")) do |radios|
        radios.radio_button(
          value: "all",
          label: I18n.t("scripts.form.project_ids.all"),
          checked: model.all_projects?
        )
        radios.radio_button(
          value: "selection",
          label: I18n.t("scripts.form.project_ids.selected"),
          checked: !model.all_projects?
        )
      end

      f.check_box_group(name: :selected_project_ids, label: I18n.t("scripts.form.selected_project_ids.title")) do |group|
        ::Project.pluck(:id, :name).each do |id, name|
          group.check_box(
            value: id.to_s,
            label: name,
            checked: !model.all_projects? && model.project_ids.include?(id)
          )
        end
      end

      f.hidden(name: :lock_version) unless model.new_record?

      f.submit(
        name: :submit,
        label: model.new_record? ? I18n.t(:button_create) : I18n.t(:button_save),
        scheme: :primary
      )
    end
  end
end
