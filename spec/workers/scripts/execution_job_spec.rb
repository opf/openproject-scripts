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

RSpec.describe Scripts::ExecutionJob do
  shared_let(:project) { create(:project) }

  let(:marker) { [] }
  let(:work_package) { create(:work_package, project:) }
  let(:actor) { create(:user) }

  before do
    $scripts_execution_job_spec_marker = marker
    allow(EnterpriseToken).to receive(:allows_to?).and_call_original
    allow(EnterpriseToken).to receive(:allows_to?).with(:running_scripts).and_return(true)
  end

  after do
    $scripts_execution_job_spec_marker = nil
  end

  describe Scripts::WorkPackageScriptJob do
    let(:run_as) { "current_user" }
    let(:event_name) { "work_package:updated" }

    let(:text) do
      <<~RUBY
        $scripts_execution_job_spec_marker << {
          event: event,
          current_user_id: current_user.id,
          work_package_id: work_package.id
        }
      RUBY
    end

    let(:script) { create(:script, text:, enabled: true, all_projects: true, run_as:) }

    subject(:perform) { described_class.perform_now(script.id, work_package, event_name, actor:) }

    context "with the feature flag enabled", with_flag: { running_scripts: true } do
      it "runs the script with the actor as current_user when run_as is current_user" do
        perform

        expect(marker).to contain_exactly(
          { event: event_name, current_user_id: actor.id, work_package_id: work_package.id }
        )
      end

      context "when run_as is system_user" do
        let(:run_as) { "system_user" }

        it "always uses User.system, regardless of the actor" do
          perform

          expect(marker).to contain_exactly(
            { event: event_name, current_user_id: User.system.id, work_package_id: work_package.id }
          )
        end
      end

      context "when run_as is current_user but no actor was captured" do
        let(:actor) { nil }

        it "falls back to User.system" do
          perform

          expect(marker).to contain_exactly(
            { event: event_name, current_user_id: User.system.id, work_package_id: work_package.id }
          )
        end
      end

      context "when the script is disabled" do
        let(:script) { create(:script, text:, enabled: false, all_projects: true, run_as:) }

        it "does not execute the script" do
          perform
          expect(marker).to be_empty
        end
      end

      context "when the script is not enabled for the work package's project" do
        let(:other_project) { create(:project) }

        before do
          script.update!(all_projects: false)
          script.projects << other_project
        end

        it "does not execute the script" do
          perform
          expect(marker).to be_empty
        end
      end

      context "when the script raises an error" do
        let(:text) { "raise 'boom'" }

        it "does not propagate the error out of perform" do
          expect { perform }.not_to raise_error
          expect(marker).to be_empty
        end
      end

      context "when the script times out" do
        let(:text) { "sleep 1" }

        before do
          stub_const("Scripts::ExecutionJob::SCRIPT_TIMEOUT_SECONDS", 0.05)
        end

        it "is interrupted by the timeout and does not propagate Timeout::Error" do
          expect { perform }.not_to raise_error
        end
      end

      context "when no Enterprise token allows :running_scripts" do
        before do
          allow(EnterpriseToken).to receive(:allows_to?).and_call_original
          allow(EnterpriseToken).to receive(:allows_to?).with(:running_scripts).and_return(false)
        end

        it "does not execute the script" do
          perform
          expect(marker).to be_empty
        end
      end
    end

    context "when the running_scripts feature flag is off" do
      it "does not execute the script" do
        expect(OpenProject::FeatureDecisions.running_scripts_active?).to be false

        perform

        expect(marker).to be_empty
      end
    end
  end

  describe Scripts::WorkPackageCommentScriptJob, with_flag: { running_scripts: true } do
    let(:journal) do
      work_package.add_journal(user: actor, notes: "a nice comment")
      work_package.save!
      work_package.journals.reload.last
    end
    let(:text) do
      <<~RUBY
        $scripts_execution_job_spec_marker << {
          journal_id: journal.id,
          work_package_id: work_package.id
        }
      RUBY
    end
    let(:script) { create(:script, text:, enabled: true, all_projects: true, run_as: "system_user") }

    it "passes both journal: and work_package: in the execution context" do
      described_class.perform_now(script.id, journal, "work_package_comment:comment")

      expect(marker).to contain_exactly(
        { journal_id: journal.id, work_package_id: work_package.id }
      )
    end
  end
end
