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
  class BaseContract < ::ModelContract
    include RequiresAdminGuard

    def self.model
      Scripts::Script
    end

    attribute :name
    attribute :description
    attribute :text do
      validate_text_syntax
    end
    attribute :enabled
    attribute :run_as
    attribute :execution_mode
    attribute :all_projects
    attribute :project_ids
    attribute :events

    # Set by the service (CreateService/UpdateService), never permitted as
    # user-facing form params in the controller's strong params. Declared here
    # so ModelContract does not flag them as illegally-changed readonly
    # attributes, mirroring Meetings::BaseContract's `attribute :author_id`.
    attribute :creator_id
    attribute :last_modified_by_user_id

    private

    def validate_text_syntax
      return if text.blank?

      # Parsed as a standalone snippet, control-flow keywords the script is
      # expected to use for an early exit (`next`, since a bare `return`
      # raises LocalJumpError inside a Proc) are themselves a parse error --
      # they are only valid inside a block. Wrap in one so the parser sees
      # the same context the text actually runs in once embedded in the
      # Proc.new { |...| } built by Scripts::ExecutionJob.
      wrapped = "Proc.new { |**_kwargs|\n#{text}\n}"
      RubyVM::AbstractSyntaxTree.parse(wrapped)
    rescue SyntaxError => e
      errors.add(:text, :invalid_syntax, detail: format_syntax_error(e))
    end

    # Rewrite the parser's error to reference the user's script line numbers
    # rather than the wrapped source's. Our wrapper prepends one line, so
    # wrapped line N corresponds to user line N-1 for N >= 2.
    def format_syntax_error(error)
      error.message
           .lines
           .map { |line| line.sub(/\A[^:]+:(\d+):/) { "line #{[Regexp.last_match(1).to_i - 1, 1].max}:" } }
           .join
           .strip
    end
  end
end
