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

# Hooks BaseServices' `:call` callback chain on WorkPackages::CreateService and
# WorkPackages::UpdateService so that scripts with execution_mode: "immediate"
# fire in the request thread, right after persistence, rather than waiting on
# the async Journals::CompletedJob (which is what routes delayed_async WP
# scripts).
#
# Delayed_async WP scripts are still handled by the existing notification
# subscribers in OpenProject::Scripts::EventResources -- see WorkPackage /
# WorkPackageComment resources, which filter to `execution_mode: "delayed_async"`.
module OpenProject::Scripts::ServiceCallbacks
  module_function

  def install!
    install_around(::WorkPackages::CreateService, action: "created")
    install_around(::WorkPackages::UpdateService, action: "updated")
  end

  # Rails' ActiveSupport::Callbacks `instance_exec`s callable callbacks, so
  # `self` inside the lambda body is the service instance, not this module.
  # Every method the lambda calls must therefore use an explicit receiver;
  # `dispatch_after_service` and friends are called via the fully qualified
  # module path below.
  def install_around(service_class, action:)
    # Guard against double-registration if to_prepare fires more than once
    # against the same class object. After a class reload the class itself is
    # replaced, so the ivar is gone and we correctly install once on the new
    # class -- that's exactly what to_prepare is for.
    marker = :"@_scripts_immediate_around_#{action}"
    return if service_class.instance_variable_get(marker)

    service_class.instance_variable_set(marker, true)
    callback = lambda do |_service, block|
      result = block.call
      ::OpenProject::Scripts::ServiceCallbacks.dispatch_after_service(action, self, result)
      result
    end
    service_class.set_callback(:call, :around, callback)
  end

  # Called after the wrapped service's perform returned. `action` is "created"
  # or "updated". Fires the corresponding WP event, plus a comment event if
  # the fresh journal has notes -- matching the two-subscriber fan-out that
  # OpenProject::Scripts::EventResources::{WorkPackage,WorkPackageComment}
  # produces via the aggregated notification.
  def dispatch_after_service(action, service, result)
    return unless result.is_a?(::ServiceResult) && result.success?
    return unless EnterpriseToken.allows_to?(:running_scripts)

    work_package = result.result
    return unless work_package.is_a?(::WorkPackage)

    actor = service.user

    fire_wp_event(action, work_package, actor)
    fire_comment_event(work_package, actor)
  rescue StandardError => e
    Rails.logger.error { "[Scripts] Service-callback dispatch failed: #{e.class}: #{e.message}" }
  end

  def fire_wp_event(action, work_package, actor)
    event_name = "work_package:#{action}"
    fire(event_name, work_package.project_id, actor, { work_package: work_package })
  end

  def fire_comment_event(work_package, actor)
    journal = work_package.journals.last
    return unless journal&.notes.present?

    action = journal.internal? ? "internal_comment" : "comment"
    event_name = "work_package_comment:#{action}"
    fire(event_name, work_package.project_id, actor, { work_package: work_package, journal: journal })
  end

  def fire(event_name, project_id, actor, context)
    ::Scripts::Script.enabled
                     .where(execution_mode: "immediate")
                     .with_event_name(event_name)
                     .find_each do |script|
      next unless script.enabled_for_project?(project_id)

      ::Scripts::Runner.new(script:, event_name:, context:, actor:).call
    end
  end
end
