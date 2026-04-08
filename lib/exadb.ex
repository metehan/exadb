defmodule Exadb do
  @moduledoc """
  A pragmatic Elixir client for ArangoDB's HTTP API.

  Exadb is designed around a simple workflow that works well in real applications:

  1. fetch a document
  2. edit the returned map
  3. persist it back

  The library stays intentionally small and module-oriented:

  - `Exadb.Api` builds ArangoDB endpoint URLs.
  - `Exadb.Http` wraps JSON request/response handling.
  - `Exadb.Doc` works with documents.
  - `Exadb.Query` runs AQL queries and cursors.
  - `Exadb.Collection`, `Exadb.Index`, and `Exadb.Graph` manage schema objects.
  - `Exadb.Database` and `Exadb.User` handle administrative endpoints.
  - `Exadb.Manager` helps copy structure and data between databases.

  Exadb returns plain maps instead of structs, which keeps it easy to integrate
  into existing code, scripts, background jobs, and operational tooling.

  ## Return values

  All public functions return `{:ok, value}` on success or `{:error, message}`
  on failure, where `message` is a binary description of the error.

  Notable exceptions:

  - `Exadb.Doc.get_one/2` returns the document map directly, `nil` when no
    document matches, or `{:error, message}` on failure.
  - `Exadb.Doc.get_property/3` returns the property value directly, `nil` when
    the property is absent, or `{:error, message}` on failure.
  - `Exadb.Doc.is_there?/2` returns a boolean directly, or `{:error, term}` on
    failure.
  - `Exadb.Query.cursor/2` additionally returns `{:done, last_page}` when a
    cursor is exhausted and there are no further pages.

  Most functions accept the same option set:

  - `:url` ArangoDB host and port, for example `"localhost:8529"`
  - `:user` ArangoDB username
  - `:pwd` ArangoDB password
  - `:db` database name
  - `:dblink` full `/_db/:name/_api` URL if you already resolved one
  - `:col` collection name for document helpers

  For the main usage patterns, see the README and guides:

  - `guides/getting-started.md`
  - `guides/document-workflow.md`
  - `guides/queries-and-cursors.md`
  - `guides/schema-and-operations.md`
  """
end
