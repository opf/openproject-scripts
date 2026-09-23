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

RSpec.describe Scripts::AdminController do
  let(:user) { create(:admin) }

  before do
    login_as user
  end

  context "when not admin" do
    let(:user) { build_stubbed(:user) }

    it "renders 403" do
      get :index
      expect(response).to have_http_status :forbidden
    end
  end

  context "when not logged in" do
    let(:user) { User.anonymous }

    it "redirects to sign in" do
      get :index
      expect(response).to redirect_to(signin_url(back_url: admin_scripts_url))
    end
  end

  describe "the running_scripts feature flag" do
    it "does not by itself gate controller access (only the admin menu item)" do
      expect(OpenProject::FeatureDecisions.running_scripts_active?).to be false

      allow(EnterpriseToken).to receive(:allows_to?).and_call_original
      allow(EnterpriseToken).to receive(:allows_to?).with(:running_scripts).and_return(true)
      get :index

      expect(response).to be_successful
    end
  end

  context "without a valid enterprise token for :running_scripts" do
    before do
      allow(EnterpriseToken).to receive(:allows_to?).and_call_original
      allow(EnterpriseToken).to receive(:allows_to?).with(:running_scripts).and_return(false)
    end

    describe "#index" do
      it "is still accessible" do
        get :index
        expect(response).to be_successful
      end
    end

    describe "#show" do
      let!(:script) { create(:script) }

      it "is still accessible" do
        get :show, params: { script_id: script.id }
        expect(response).to be_successful
      end
    end

    describe "#destroy" do
      let!(:script) { create(:script) }

      it "is still accessible" do
        delete :destroy, params: { script_id: script.id }
        expect(response).to be_redirect
      end
    end

    describe "#new" do
      it "renders 403" do
        get :new
        expect(response).to have_http_status :forbidden
      end
    end

    describe "#create" do
      it "renders 403" do
        post :create, params: { script: { name: "Foo", text: "1", run_as: "current_user" } }
        expect(response).to have_http_status :forbidden
      end
    end

    describe "#edit" do
      let!(:script) { create(:script) }

      it "renders 403" do
        get :edit, params: { script_id: script.id }
        expect(response).to have_http_status :forbidden
      end
    end

    describe "#update" do
      let!(:script) { create(:script) }

      it "renders 403" do
        put :update, params: { script_id: script.id, script: { name: "New name" } }
        expect(response).to have_http_status :forbidden
      end
    end
  end

  context "with a valid enterprise token for :running_scripts" do
    before do
      allow(EnterpriseToken).to receive(:allows_to?).and_call_original
      allow(EnterpriseToken).to receive(:allows_to?).with(:running_scripts).and_return(true)
    end

    describe "#index" do
      it "renders the index page" do
        get :index
        expect(response).to be_successful
        expect(response).to render_template "index"
      end
    end

    describe "#new" do
      it "renders the new page" do
        get :new
        expect(response).to be_successful
        expect(assigns[:script]).to be_new_record
        expect(response).to render_template "new"
      end
    end

    describe "#create" do
      let(:script_params) do
        { name: "My Script", text: "1 + 1", run_as: "current_user", enabled: "1", project_ids: "all" }
      end

      it "creates the script and redirects to index" do
        expect { post :create, params: { script: script_params } }
          .to change(Scripts::Script, :count).by(1)

        expect(flash[:notice]).to be_present
        expect(response).to redirect_to(action: :index)
      end

      it "sets the creator to the current user" do
        post :create, params: { script: script_params }
        expect(Scripts::Script.last.creator).to eq user
      end

      context "with invalid params" do
        let(:script_params) { { name: "", text: "", run_as: "current_user" } }

        it "renders the new page again" do
          post :create, params: { script: script_params }
          expect(response).to render_template "new"
          expect(response).to have_http_status :unprocessable_entity
        end
      end
    end

    describe "#edit" do
      let!(:script) { create(:script) }

      it "renders the edit page" do
        get :edit, params: { script_id: script.id }
        expect(response).to be_successful
        expect(assigns[:script]).to eq script
        expect(response).to render_template "edit"
      end
    end

    describe "#update" do
      let!(:script) { create(:script, name: "Old name") }

      it "updates the script and redirects to index" do
        put :update, params: { script_id: script.id, script: { name: "New name", lock_version: script.lock_version } }

        expect(response).to redirect_to(action: :index)
        expect(script.reload.name).to eq "New name"
      end

      context "when the lock_version is stale" do
        before do
          Scripts::Script.find(script.id).update!(description: "concurrent change")
        end

        it "re-renders edit with a conflict error and does not persist the change" do
          put :update, params: { script_id: script.id, script: { name: "New name", lock_version: script.lock_version } }

          expect(response).to render_template "edit"
          expect(response).to have_http_status :unprocessable_entity
          expect(script.reload.name).not_to eq "New name"
        end
      end

      context "when saving raises ActiveRecord::StaleObjectError directly" do
        before do
          allow(Scripts::UpdateService).to receive(:new).and_raise(ActiveRecord::StaleObjectError.new(script, "update"))
        end

        it "rescues the error and re-renders edit with a locking conflict message" do
          put :update, params: { script_id: script.id, script: { name: "New name" } }

          expect(response).to render_template "edit"
          expect(response).to have_http_status :unprocessable_entity
          expect(flash[:error]).to eq I18n.t(:notice_locking_conflict)
        end
      end
    end

    describe "#destroy" do
      let!(:script) { create(:script) }

      it "destroys the script" do
        expect { delete :destroy, params: { script_id: script.id } }
          .to change(Scripts::Script, :count).by(-1)

        expect(flash[:notice]).to be_present
        expect(response).to be_redirect
      end
    end
  end
end
