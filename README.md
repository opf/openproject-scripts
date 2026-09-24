# OpenProject Scripts (Experimental)

> ⚠️ **Experimental code — do not install on any critical or production infrastructure.**
> This plugin lets an admin execute arbitrary Ruby with full application privileges. It has not
> been hardened, audited, or reviewed for production use, and it is not intended to be.

## Purpose

This plugin is an experiment, not a product. Its goal is to get a feel for what *radical
extensibility* in OpenProject could be like — inspired by Jira's ScriptRunner — by giving an
instance admin the ability to write custom Ruby and have it run automatically on domain events
(work packages or projects created/updated, comments added, time entries or attachments created).

The point is to **trigger new ideas** about what extensibility in OpenProject might look like, not
to arrive at a finished feature. Nothing here should be read as a proposal to ship "exactly this."
If it sparks a direction worth pursuing, that direction will very likely look different from this
experiment once real design, security, and product considerations are applied.

## What it does

An admin writes Ruby code, saves it as a `Scripts::Script`, and subscribes it to one or more of the
same events OpenProject's built-in Webhooks feature already fires on. When a matching event occurs,
the script runs asynchronously inside a `Proc`, receiving the event name, the acting user, and the
live domain object(s) involved (the work package, project, journal, etc.).

It sits behind two independent gates — a `running_scripts` feature flag (off by default outside
development) and an Enterprise-token check — as a minimum safety net, not as a substitute for
treating this as untrusted, unreviewed code.

This is deliberately modeled on OpenProject's built-in Webhooks feature — same event catalog,
same admin menu placement (a sibling of Webhooks under *Administration → API and webhooks*), same
async delivery via a background job.

See `docs/development/create-openproject-plugin` in OpenProject core for the general plugin
mechanism this follows.

## Requirements

- OpenProject >= 17.0.0
- An Enterprise token granting the `running_scripts` feature, to actually create/edit/enable
  scripts through the admin UI (the admin menu item, and read-only access to existing scripts,
  remain visible without one — an upsell banner is shown instead).

## Installation

Add this plugin to your OpenProject installation's `Gemfile.plugins`, inside the `opf_plugins`
group:

```ruby
group :opf_plugins do
  gem "openproject-scripts", path: "../plugins/openproject-scripts"
end
```

Then run `bundle install` and `bundle exec rails db:migrate` from your OpenProject core checkout.

For Docker-based installations, see the
[Docker plugin installation guide](https://www.openproject.org/docs/installation-and-operations/installation/docker/#openproject-plugins).
For packaged (deb/rpm) installations, see the
[packaged plugin installation guide](https://www.openproject.org/docs/installation-and-operations/configuration/plugins/#adding-plugins-debrpm-packages).

## Uninstallation

Remove the `gem "openproject-scripts", ...` line from `Gemfile.plugins` and run `bundle install`
again. Existing `scripts_*` database tables are left in place; drop them manually via a migration
if you want them removed too.

## Bug reports and contributions

Please report issues and open pull requests against this plugin's repository.

## License

GPLv3, matching OpenProject core. See `COPYRIGHT` and `LICENSE` in OpenProject core for details.
