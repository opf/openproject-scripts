# OpenProject Scripts

Lets an instance administrator write custom Ruby code and register it to run automatically when
certain domain events occur — work packages or projects created/updated, work package comments
added, time entries or attachments created. When a matching event fires, the script executes
asynchronously inside a `Proc`, receiving the event name, the acting user, and the live domain
object(s) involved (the work package, project, journal, etc.).

This is deliberately modeled on OpenProject's built-in Webhooks feature — same event catalog,
same admin menu placement (a sibling of Webhooks under *Administration → API and webhooks*), same
async delivery via a background job.

Because it grants an admin the ability to run arbitrary Ruby with full application privileges,
this plugin is gated behind two independent switches, both of which must be satisfied:

- the `running_scripts` feature flag (off by default in production/test, on by default in
  development), toggleable at *Administration → Settings → Experimental*, and
- an Enterprise token that grants the `running_scripts` feature.

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
