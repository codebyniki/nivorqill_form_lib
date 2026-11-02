# Integrating and migrating

Create a controller with stable fields, a user-scoped `DraftKey` and a store;
place `NivorquillForm` around the fields, resolve recovery before editing and
own the controller until the view is removed. See the [README](../README.md)
and [API guide](API.md). Persistence is opt-in and must not contain secrets.

For beta.1 migrations, the README maps the former `Draft*` widget and schema
names to `Nivorquill*`. Draft storage types and existing keys remain unchanged.
There are no deprecated aliases. Version schemas when persisted meanings change
and provide a deterministic `migrate` callback for old values. Unknown fields
are ignored; a draft with no currently recognized persistable fields is not
shown as a recovery candidate and is not deleted automatically.

The `dateTime` codec retains UTC instant behavior. Use `dateOnly` only for calendar
values, and migrate existing stored values deliberately when changing codecs.
