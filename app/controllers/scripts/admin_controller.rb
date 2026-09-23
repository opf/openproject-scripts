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
  class AdminController < ::ApplicationController
    layout "admin"

    before_action :require_admin
    guard_enterprise_feature(:running_scripts, except: %i[index show destroy])
    before_action :find_script, only: %i[show edit update destroy]

    menu_item :plugin_scripts

    def index
      @scripts = Scripts::Script.all
    end

    def show; end

    def new
      @script = Scripts::Script.new_default
    end

    def edit; end

    def create
      call = Scripts::CreateService.new(user: current_user).call(permitted_script_params)
      if call.success?
        flash[:notice] = I18n.t(:notice_successful_create)
        redirect_to action: :index
      else
        @script = call.result
        render action: :new, status: :unprocessable_entity
      end
    end

    def update
      call = Scripts::UpdateService.new(user: current_user, model: @script).call(permitted_script_params)
      if call.success?
        flash[:notice] = I18n.t(:notice_successful_update)
        redirect_to action: :index
      else
        @script = call.result
        render action: :edit, status: :unprocessable_entity
      end
    rescue ActiveRecord::StaleObjectError
      flash.now[:error] = I18n.t(:notice_locking_conflict)
      render action: :edit, status: :unprocessable_entity
    end

    def destroy
      call = Scripts::DeleteService.new(user: current_user, model: @script).call
      if call.success?
        flash[:notice] = I18n.t(:notice_successful_delete)
      else
        flash[:error] = I18n.t(:error_failed_to_delete_entry)
      end

      redirect_to action: :index, status: :see_other
    end

    private

    def find_script
      @script = Scripts::Script.find(params.expect(:script_id))
    end

    def permitted_script_params
      params.expect(script: [:name, :description, :text, :enabled, :run_as, :lock_version,
                             :project_ids, { selected_project_ids: [], events: [] }])
    end
  end
end
