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
require "contracts/shared/model_contract_shared_context"

RSpec.describe Scripts::BaseContract do
  include_context "ModelContract shared context"

  shared_let(:admin_user) { create(:admin) }

  let(:script) do
    Scripts::Script.new(
      name: "My Script",
      text: "1 + 1",
      run_as: "current_user",
      creator_id: admin_user.id,
      last_modified_by_user_id: admin_user.id
    )
  end
  let(:contract) { described_class.new(script, current_user) }
  let(:current_user) { admin_user }

  it_behaves_like "contract is valid for active admins and invalid for regular users"

  describe "text syntax validation" do
    context "with syntactically valid Ruby" do
      before { script.text = "Rails.logger.info('hi')" }

      it_behaves_like "contract is valid"
    end

    context "with syntactically invalid Ruby" do
      before { script.text = "def foo" }

      it_behaves_like "contract is invalid", text: %i[invalid_syntax]
    end

    context "with a top-level next, as recommended for early-exit instead of a bare return" do
      before { script.text = "if 1 == 1\n  next\nend" }

      it_behaves_like "contract is valid"
    end

    context "when text is blank" do
      before { script.text = "" }

      it_behaves_like "contract is invalid", text: %i[blank]
    end
  end

  include_examples "contract reuses the model errors"
end
