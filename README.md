# Exadb

Exadb is a pragmatic Elixir client for ArangoDB's HTTP API.

It is built for the way teams actually work with ArangoDB in real applications:

- fetch a document
- edit it as a plain Elixir map
- persist it back
- run AQL when the job is bigger than one document
- stream cursor pages when result sets grow large

That workflow has been used in production for years. The code was stable and useful long before it was packaged for public release.

Exadb stays intentionally small and direct:

- plain maps in and out
- minimal ceremony
- focused modules for documents, queries, collections, graphs, users, and databases
- easy to understand request flow when something needs debugging

If you want a thin, dependable layer over ArangoDB instead of a large abstraction that hides the database, Exadb is the right shape.

## Installation

Add `:exadb` to your dependencies:

```elixir
defp deps do
  [
    {:exadb, "~> 0.1.0"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

## Configuration

The client reads these environment variables by default:

- `ADB_URL` defaults to `arangodb:8529`
- `ADB_USER` defaults to `root`
- `ADB_PWD` defaults to the same value as `ADB_USER`
- `ADB_DB` defaults to the same value as `ADB_USER`, then `default`

You can also pass explicit options to every function:

```elixir
opts = [url: "localhost:8529", user: "root", pwd: "secret", db: "example"]
```

This makes it easy to use Exadb in both styles:

- environment-driven application code
- explicit per-call scripts, tasks, tests, or admin tooling

## Why Exadb

- The core document workflow is simple and fast.
- `persist/2` is smart: insert new maps, update fetched documents.
- You keep working with ordinary maps instead of custom structs.
- Query helpers are thin and predictable.
- Database and user helpers make multi-tenant or admin flows straightforward.

## Feature List

Exadb currently covers these ArangoDB workflows:

- Document CRUD with plain maps via `Exadb.Doc.fetch/2`, `persist/2`, `persist_multi/2`, `persist_new/2`, `vaporize/2`, and `vaporize_by_id/2`
- Multi-document and lookup helpers via `Exadb.Doc.fetch_multi/2`, `get/3`, `get_one/2`, and `is_there?/2`
- Targeted document property updates via `Exadb.Doc.update_property/4`, `push/4`, `pop/4`, `switch_on/3`, and `switch_off/3`
- AQL execution with bind variables via `Exadb.Query.run/3`
- Cursor pagination and streaming via `Exadb.Query.cursor/2` and `cursor_stream/2`
- Collection management via `Exadb.Collection.new_collection/3`, `new_edge/3`, `new/4`, `rename/3`, `get_all/1`, `get/2`, `is_there?/2`, and `delete/2`
- Index management via `Exadb.Index.new/3`, `list/2`, `clean_list/2`, and `delete/2`
- Named graph management via `Exadb.Graph.new/4`, `get_all/1`, and `delete/2`
- Database administration via `Exadb.Database.get_all/1`, `user_dbs/2`, `new/2`, `new_db_and_user/3`, and `vaporize/2`
- User administration and database grants via `Exadb.User.new/2`, `get_all/1`, `get/2`, `replace/3`, `update/3`, `give_access/3`, `remove_access/3`, and `vaporize/2`
- Database and collection copy helpers via `Exadb.Manager.copy_database/3`, `copy_collection_data/2`, `copy_collection_data_filtered/2`, `copy_query/2`, and `clean_database/1`
- URL and database-link helpers via `Exadb.Api.url/1`, `root/1`, and `db/2`

## The Main Workflow

The most natural Exadb workflow is:

1. fetch a document
2. edit the map
3. persist it back

`Exadb.Doc.persist/2` decides what to do from the content you give it.

- If the map is new, it creates a document.
- If the map already contains ArangoDB document metadata from a previous fetch, it updates the existing document.

That means the common edit cycle stays clean:

```elixir
opts = [url: "localhost:8529", user: "root", pwd: "secret", db: "app", col: "users"]

user = Exadb.Doc.fetch("users/123", opts)

updated_user =
  user
  |> Map.put("display_name", "Jane Doe")
  |> Map.put("active", true)
  |> Exadb.Doc.persist(opts)
```

No separate create-vs-update branch in your application code.

## Query And Cursor Workflow

Not every job is a single-document workflow.

When the work is better expressed in AQL, Exadb gives you a second natural path:

1. write the AQL you actually want
2. pass bind variables as a plain map
3. read the decoded result
4. move to cursor paging or streaming when the result set grows

That means you can use Exadb comfortably in both modes:

- document-centric application code with `Exadb.Doc`
- query-centric reporting, search, migration, and batch processing with `Exadb.Query`

For straightforward AQL execution:

```elixir
opts = [url: "localhost:8529", user: "root", pwd: "secret", db: "app"]

Exadb.Query.run(
  "FOR user IN users FILTER user.active == @active SORT user.email RETURN user",
  %{active: true},
  opts
)
```

For cursor-based reads, start a cursor with a map:

```elixir
first_page =
  Exadb.Query.cursor(
    %{
      query: "FOR user IN users SORT user.email RETURN user",
      batchSize: 100
    },
    opts
  )
```

If ArangoDB returns more results, pass the cursor response back into `Exadb.Query.cursor/2` to fetch the next page.

If you want a cleaner streaming model, use `Exadb.Query.cursor_stream/2`:

```elixir
Exadb.Query.cursor_stream(
  %{
    query: "FOR user IN users SORT user.email RETURN user",
    batchSize: 100
  },
  opts
)
|> Enum.each(fn page ->
  Enum.each(page["result"], fn user ->
    IO.inspect(user["email"])
  end)
end)
```

This is especially useful for:

- reporting
- export jobs
- background processing
- data migrations
- copying data between databases

### Create New Documents

For new data, just pass a plain map:

```elixir
opts = [url: "localhost:8529", user: "root", pwd: "secret", db: "app", col: "users"]

created =
  Exadb.Doc.persist(%{
    "email" => "jane@example.com",
    "display_name" => "Jane",
    "active" => true,
    "roles" => ["admin"]
  }, opts)

created["_id"]
#=> "users/123"
```

### Clone Or Reinsert Without Metadata

If you fetched a document and want to store it as a fresh record instead of updating the existing one, use `persist_new/2`.

```elixir
copy =
  created
  |> Map.put("email", "copy@example.com")
  |> Exadb.Doc.persist_new(opts)
```

## Usage

### Documents

Exadb is at its best when your application logic is document-centric.

```elixir
opts = [url: "localhost:8529", user: "root", pwd: "secret", db: "app", col: "users"]

created = Exadb.Doc.persist(%{"email" => "jane@example.com", "tags" => ["new"]}, opts)
found = Exadb.Doc.fetch(created["_id"], opts)

retagged =
  found
  |> Map.put("tags", ["new", "customer"])
  |> Exadb.Doc.persist(opts)

Exadb.Doc.push(retagged["_id"], "tags", "beta", opts)
Exadb.Doc.pop(retagged["_id"], "tags", "new", opts)
Exadb.Doc.switch_on(retagged["_id"], "active", opts)
```

Other useful document helpers:

- `Exadb.Doc.fetch_multi/2`
- `Exadb.Doc.get/3`
- `Exadb.Doc.get_one/2`
- `Exadb.Doc.is_there?/2`
- `Exadb.Doc.vaporize/2`
- `Exadb.Doc.vaporize_by_id/2`

### Queries

For AQL-heavy parts of an application, use `Exadb.Query`.

```elixir
opts = [url: "localhost:8529", user: "root", pwd: "secret", db: "app"]

Exadb.Query.run(
  "FOR user IN users FILTER user.email == @email RETURN user",
  %{email: "jane@example.com"},
  opts
)
```

If you need cursor-based processing, `Exadb.Query.cursor/2` and `Exadb.Query.cursor_stream/2` let you work through larger result sets without changing mental models.

### Collections, Edges, And Indexes

Schema-level operations stay just as direct.

```elixir
db_opts = [url: "localhost:8529", user: "root", pwd: "secret", db: "app"]
dblink = Exadb.Api.db(nil, db_opts)

Exadb.Collection.new_collection("users", %{}, db_opts)
Exadb.Collection.new_edge("follows", %{}, db_opts)

Exadb.Index.new(
  "users",
  %{"type" => "persistent", "fields" => ["email"], "unique" => true},
  dblink
)
```

This is enough to keep bootstrapping, migration scripts, and admin tooling readable.

### Graphs

When you need named graph setup, Exadb keeps that API small too:

```elixir
db_opts = [url: "localhost:8529", user: "root", pwd: "secret", db: "app"]
dblink = Exadb.Api.db(nil, db_opts)

Exadb.Graph.new(
  "social",
  [
    %{
      collection: "follows",
      from: ["users"],
      to: ["users"]
    }
  ],
  [],
  dblink
)
```

### Users And Databases

Exadb also covers the practical admin operations needed by real systems.

```elixir
admin_opts = [url: "localhost:8529", user: "root", pwd: "secret"]

Exadb.Database.new_db_and_user("tenant_a", "tenant-secret", admin_opts)
Exadb.User.give_access("tenant_a", "tenant_a", Keyword.merge(admin_opts, level: "rw"))
```

For operational data movement, `Exadb.Manager` also includes higher-level copy helpers.
That covers cases such as copying a database schema into a new tenant database,
cloning collection data, or moving records selected by a custom AQL filter.

That makes it useful not just in application code, but also in:

- provisioning tasks
- tenant setup flows
- migration scripts
- operational admin commands

### URL Helpers

If you want to build URLs once and pass them through explicitly, the API helpers are available too:

```elixir
Exadb.Api.url(url: "localhost:8529", user: "root", pwd: "secret")
#=> "http://root:secret@localhost:8529"

Exadb.Api.root(url: "localhost:8529", user: "root", pwd: "secret")
#=> "http://root:secret@localhost:8529/_api"

Exadb.Api.db("app", url: "localhost:8529", user: "root", pwd: "secret")
#=> "http://root:secret@localhost:8529/_db/app/_api"
```

## Testing And Documentation

Run the normal test suite:

```bash
mix test
```

Run integration tests against a real ArangoDB instance:

```bash
mix test --include integration
EXADB_RUN_INTEGRATION=1 mix test
```

The integration suite supports these environment variables:

- `EXADB_TEST_DB`, default `mix_test`
- `EXADB_TEST_URL`, default `localhost:8529`
- `EXADB_TEST_USER`, default `root`
- `EXADB_TEST_PWD`, default `root`

By default, the integration suite recreates the `mix_test` database and matching user before the run and removes them afterwards.

Generate docs locally with:

```bash
mix docs
```

Additional guides:

- `guides/getting-started.md`
- `guides/document-workflow.md`
- `guides/queries-and-cursors.md`
- `guides/schema-and-operations.md`
- `guides/testing.md`

Exadb is production-proven code that stayed private for a long time. Its design is direct because it grew out of repeated real-world use, not from trying to model every possible abstraction up front.

If you want a client that makes ArangoDB pleasant to use from Elixir without forcing you into a heavy framework, Exadb is ready for that job.
