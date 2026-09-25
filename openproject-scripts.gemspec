# frozen_string_literal: true

$:.push File.expand_path("lib", __dir__)

require "open_project/scripts/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "openproject-scripts"
  s.version     = OpenProject::Scripts::VERSION
  s.required_ruby_version = ">= 3.4"

  s.authors     = "OpenProject GmbH"
  s.email       = "info@openproject.com"
  s.homepage    = "https://community.openproject.org/projects/scripts"
  s.summary     = "OpenProject Scripts"
  s.description = "Experiment: Not for production! Provides an admin feature to run custom Ruby code in response to domain events."
  s.license     = "GPLv3"

  s.files = Dir["{app,config,db,lib}/**/*"] + %w(CHANGELOG.md README.md)
  s.metadata["rubygems_mfa_required"] = "true"
end
