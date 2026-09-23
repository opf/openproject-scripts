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

require "spec_helper"

RSpec.describe OpenProject::Scripts::EventResources::WorkPackage do
  subject(:notification_sent) do
    OpenProject::Notifications.send(OpenProject::Events::AGGREGATED_WORK_PACKAGE_JOURNAL_READY, journal:, send_mail: false)
  end

  shared_let(:author) { create(:user) }
  shared_let(:updater) { create(:user) }
  shared_let(:work_package) { User.execute_as(author) { create(:work_package) } }

  let!(:created_script) { create(:script, enabled: true, all_projects: true, event_names: ["work_package:created"]) }
  let!(:updated_script) { create(:script, enabled: true, all_projects: true, event_names: ["work_package:updated"]) }
  let!(:disabled_script) { create(:script, enabled: false, all_projects: true, event_names: ["work_package:updated"]) }

  context "when the journal is the initial one (work package created)" do
    let(:journal) { work_package.journals.reload.first }

    it "enqueues the job for scripts subscribed to work_package:created, with the journal's user as actor" do
      notification_sent

      expect(Scripts::WorkPackageScriptJob).to have_been_enqueued.with(
        created_script.id, work_package, "work_package:created", actor: author
      )
    end

    it "does not enqueue the job for scripts subscribed to work_package:updated" do
      notification_sent

      expect(Scripts::WorkPackageScriptJob).not_to have_been_enqueued.with(
        updated_script.id, anything, anything, actor: anything
      )
    end
  end

  context "when the journal is not the initial one (work package updated)" do
    let(:journal) do
      work_package.add_journal(user: updater, notes: "Updated the work package")
      work_package.save!
      work_package.journals.reload.last
    end

    it "enqueues the job for scripts subscribed to work_package:updated, with the journal's user as actor" do
      notification_sent

      expect(Scripts::WorkPackageScriptJob).to have_been_enqueued.with(
        updated_script.id, work_package, "work_package:updated", actor: updater
      )
    end

    it "does not enqueue the job for scripts subscribed to work_package:created" do
      notification_sent

      expect(Scripts::WorkPackageScriptJob).not_to have_been_enqueued.with(
        created_script.id, anything, anything, actor: anything
      )
    end

    it "does not enqueue the job for a disabled script" do
      notification_sent

      expect(Scripts::WorkPackageScriptJob).not_to have_been_enqueued.with(
        disabled_script.id, anything, anything, actor: anything
      )
    end
  end
end
