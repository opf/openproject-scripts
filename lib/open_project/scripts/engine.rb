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

# Prevent load-order problems in case openproject-plugins is listed after this
# plugin in the Gemfile or not at all
require "open_project/plugins"

module OpenProject::Scripts
  class Engine < ::Rails::Engine
    engine_name :openproject_scripts

    include OpenProject::Plugins::ActsAsOpEngine

    register "openproject-scripts",
             author_url: "https://www.openproject.org",
             requires_openproject: ">= 17.0.0" do
      menu :admin_menu,
           :plugin_scripts,
           { controller: "/scripts/admin", action: :index },
           if: Proc.new { User.current.admin? && OpenProject::FeatureDecisions.running_scripts_active? },
           parent: :api_and_webhooks,
           enterprise_feature: "running_scripts",
           caption: :"scripts.plural"
    end

    initializer "openproject_scripts.feature_decisions" do
      OpenProject::FeatureDecisions.add :running_scripts,
                                        description: "Enables the Scripts admin feature for running custom Ruby " \
                                                     "code in response to domain events.",
                                        allow_enabling: true
    end

    initializer "openproject_scripts.subscribe_to_notifications" do |app|
      app.config.after_initialize do
        ::OpenProject::Scripts::EventResources.subscribe!
      end
    end

    initializer "openproject_scripts.install_service_callbacks" do |app|
      require "open_project/scripts/service_callbacks"
      # to_prepare fires on every dev-mode class reload, so the set_callback
      # registrations survive the reload that would otherwise wipe them off
      # WorkPackages::{Create,Update}Service.
      app.config.to_prepare do
        ::OpenProject::Scripts::ServiceCallbacks.install!
      end
    end
  end
end
