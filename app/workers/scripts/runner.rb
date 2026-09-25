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

require "timeout"

module Scripts
  # Runs one script with a given event/context/actor. Called from
  # Scripts::ExecutionJob (delayed_async path) and from the notification
  # subscribers / WorkPackage service callbacks (immediate path).
  class Runner
    SCRIPT_TIMEOUT_SECONDS = 10

    attr_reader :script, :event_name, :context, :actor

    def initialize(script:, event_name:, context:, actor: nil)
      @script = script
      @event_name = event_name
      @context = context
      @actor = actor
    end

    def call
      payload = script_payload
      Timeout.timeout(SCRIPT_TIMEOUT_SECONDS) do
        script_proc(payload.keys).call(**payload)
      end
    rescue StandardError => e
      log_failure(e)
    end

    private

    def script_payload
      { event: event_name, current_user: resolve_current_user }.merge(context)
    end

    def resolve_current_user
      if script.run_as == "current_user" && actor
        actor
      else
        User.system
      end
    end

    # Builds `Proc.new { |event:, current_user:, work_package:, ...| <script.text> }`,
    # binding every payload key as a real local variable the script body can
    # reference directly (e.g. `work_package.id`), rather than hiding them
    # behind a **context hash. The interpolated body is arbitrary
    # admin-authored Ruby, so no comment block can document its literal
    # appearance the way this cop expects.
    def script_proc(payload_keys)
      isolated_binding = Object.new.instance_eval { binding }
      params = payload_keys.map { |key| "#{key}:" }.join(", ")
      eval( # rubocop:disable Security/Eval, Style/DocumentDynamicEvalDefinition
        "Proc.new { |#{params}| \n#{script.text}\n }",
        isolated_binding,
        __FILE__,
        __LINE__ - 3
      )
    end

    def log_failure(error)
      Rails.logger.error do
        "[Scripts] Script ##{script.id} (#{script.name}) failed on #{event_name}: " \
          "#{error.class}: #{error.message}\n#{error.backtrace&.join("\n")}"
      end
    end
  end
end
