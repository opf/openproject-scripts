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
  module Admin
    class RowComponent < ApplicationComponent
      include ApplicationHelper
      include OpPrimer::ComponentHelpers
      include OpTurbo::Streamable

      def initialize(script:)
        @script = script
        super
      end

      def enabled_label
        @script.enabled? ? I18n.t(:general_text_yes) : I18n.t(:general_text_no)
      end

      def enabled_scheme
        @script.enabled? ? :success : :secondary
      end

      def run_as_label
        I18n.t("scripts.form.run_as.#{@script.run_as}")
      end

      def execution_mode_label
        I18n.t("scripts.form.execution_mode.#{@script.execution_mode}.label")
      end

      def events_summary
        I18n.t("scripts.label_x_events", count: @script.event_names.size)
      end
    end
  end
end
