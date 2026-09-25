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
  class ExecutionJob < Scripts::ScriptJob
    attr_reader :resource, :actor

    def perform(script_id, resource, event_name, actor: nil)
      @resource = resource
      @actor = actor
      super(script_id, event_name)

      return log_skip("script not found") if script.nil?
      return log_skip("running_scripts feature flag is off") unless OpenProject::FeatureDecisions.running_scripts_active?
      return log_skip("no Enterprise token allows :running_scripts") unless EnterpriseToken.allows_to?(:running_scripts)
      return log_skip("script is disabled") unless script.enabled?
      return log_skip("script not enabled for this project") unless accepted_in_project?

      Scripts::Runner.new(script:, event_name:, context: execution_context, actor:).call
    end

    def accepted_in_project?
      script.enabled_for_project?(project_id)
    end

    def project_id # rubocop:disable Rails/Delegate
      resource.project_id
    end

    def context_key
      raise SubclassResponsibilityError
    end

    def execution_context
      { context_key => resource }
    end

    private

    def log_skip(reason)
      Rails.logger.info { "[Scripts] Skipping script ##{script_id} for #{event_name}: #{reason}" }
    end
  end
end
