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

RSpec.describe Scripts::CreateService, type: :model do
  shared_let(:admin) { create(:admin) }

  let(:instance) { described_class.new(user: admin) }
  let(:params) do
    {
      name: "My Script",
      description: "Does things",
      text: "1 + 1",
      enabled: true,
      run_as: "current_user",
      project_ids: "all",
      events: ["work_package:created", "work_package:updated"]
    }
  end

  subject(:service_result) { instance.call(**params) }

  it "creates the script" do
    expect(service_result).to be_success
    expect(service_result.result).to be_persisted
  end

  it "sets the creator and last_modified_by_user to the calling user" do
    script = service_result.result

    expect(script.creator_id).to eq admin.id
    expect(script.last_modified_by_user_id).to eq admin.id
  end

  it "persists the selected events" do
    script = service_result.result

    expect(script.event_names).to contain_exactly("work_package:created", "work_package:updated")
  end

  it "sets all_projects when project_ids is 'all'" do
    expect(service_result.result.all_projects).to be true
  end

  context "when project_ids is a selection of specific projects" do
    let(:project) { create(:project) }
    let(:params) { super().merge(project_ids: "selection", selected_project_ids: [project.id]) }

    it "scopes the script to the selected projects only" do
      script = service_result.result

      expect(script.all_projects).to be false
      expect(script.projects).to contain_exactly(project)
    end
  end

  context "when the user is not an admin" do
    let(:admin) { create(:user) }

    it "fails with an unauthorized error and does not persist anything" do
      expect { service_result }.not_to change(Scripts::Script, :count)
      expect(service_result).not_to be_success
      expect(service_result.errors[:base]).to be_present
    end
  end
end
