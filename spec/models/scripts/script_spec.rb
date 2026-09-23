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

RSpec.describe Scripts::Script do
  subject(:script) { build(:script) }

  describe "validations" do
    describe "#name" do
      it "is invalid without a name" do
        script.name = nil
        expect(script).not_to be_valid
        expect(script.errors).to have_key(:name)
      end

      it "is invalid with a duplicate name, case-insensitively" do
        create(:script, name: "My Script")
        script.name = "my script"

        expect(script).not_to be_valid
        expect(script.errors).to have_key(:name)
      end
    end

    describe "#text" do
      it "is invalid without text" do
        script.text = nil
        expect(script).not_to be_valid
        expect(script.errors).to have_key(:text)
      end
    end

    describe "#run_as" do
      it "is valid for current_user" do
        script.run_as = "current_user"
        expect(script).to be_valid
      end

      it "is valid for system_user" do
        script.run_as = "system_user"
        expect(script).to be_valid
      end

      it "is invalid for any other value" do
        script.run_as = "someone_else"
        expect(script).not_to be_valid
        expect(script.errors).to have_key(:run_as)
      end
    end
  end

  describe ".enabled" do
    it "returns only the enabled scripts" do
      enabled_script = create(:script, enabled: true)
      create(:script, enabled: false)

      expect(described_class.enabled).to contain_exactly(enabled_script)
    end
  end

  describe ".with_event_name" do
    let(:events) { %w(work_package:updated work_package:created) }

    before do
      script.enabled = true
      script.event_names = events
      script.save!
    end

    it "finds the enabled script subscribed to the given event name" do
      expect(described_class.with_event_name(events[0]).first).to eq(script)
      expect(described_class.with_event_name(events[1]).first).to eq(script)
    end

    it "does not find disabled scripts" do
      script.update_column(:enabled, false)

      expect(described_class.with_event_name(events[0])).to be_empty
    end
  end

  describe ".new_default" do
    it "returns a new script with the conservative defaults" do
      default = described_class.new_default

      expect(default).to be_new_record
      expect(default.all_projects).to be true
      expect(default.enabled).to be false
      expect(default.run_as).to eq "current_user"
    end
  end

  describe "#enabled_for_project?" do
    let(:project1) { create(:project) }

    before do
      script.all_projects = false
      script.projects << project1
      script.save!
    end

    it "is true for a selected project" do
      expect(script).to be_enabled_for_project(project1.id)
    end

    it "is false for a project that has not been selected" do
      expect(script).not_to be_enabled_for_project(project1.id + 1)
    end

    context "when all_projects is true" do
      before { script.all_projects = true }

      it "is true regardless of the project" do
        expect(script).to be_enabled_for_project(project1.id + 1)
      end
    end
  end

  describe "#event_names=" do
    it "builds the events association from the given names" do
      script.event_names = %w(work_package:created project:updated)
      script.save!

      expect(script.event_names).to contain_exactly("work_package:created", "project:updated")
    end
  end
end
