# Getting Started

Exadb is easiest to adopt when you start with one collection and one workflow:

1. connect to ArangoDB
2. fetch a document
3. edit the map
4. persist it back

## Choose a configuration style

Exadb supports both environment-driven and explicit configuration.

Environment-driven usage:

```bash
export ADB_URL=localhost:8529
export ADB_USER=root
export ADB_PWD=secret
export ADB_DB=app
```

```elixir
{:ok, results} = Exadb.Doc.get(%{"email" => "jane@example.com"}, 10, col: "users")
```

Explicit per-call usage:

```elixir
opts = [url: "localhost:8529", user: "root", pwd: "secret", db: "app", col: "users"]

{:ok, results} = Exadb.Doc.get(%{"email" => "jane@example.com"}, 10, opts)
```

Use environment variables when most of your application talks to one database.

Use explicit options when you are writing scripts, admin tooling, tests, or multi-database flows.

## The first useful workflow

```elixir
opts = [url: "localhost:8529", user: "root", pwd: "secret", db: "app", col: "users"]

{:ok, user} = Exadb.Doc.fetch("users/123", opts)

user
|> Map.put("display_name", "Jane Doe")
|> Map.put("active", true)
|> Exadb.Doc.persist(opts)
```

This is the core Exadb experience.

You work with plain maps.

You do not need separate create and update service layers just to store documents.

## New documents

```elixir
opts = [url: "localhost:8529", user: "root", pwd: "secret", db: "app", col: "users"]

Exadb.Doc.persist(
  %{
    "email" => "jane@example.com",
    "display_name" => "Jane",
    "roles" => ["admin"]
  },
  opts
)
```

If the map has ArangoDB metadata like `_id` and `_rev`, `persist/2` updates.

If it does not, `persist/2` creates.

## Useful modules at a glance

- `Exadb.Doc` for document read/write operations
- `Exadb.Query` for AQL and cursors
- `Exadb.Collection` for collections and edges
- `Exadb.Index` for index management
- `Exadb.Graph` for graph definitions
- `Exadb.Database` and `Exadb.User` for admin tasks

## Where to go next

- Read `guides/document-workflow.md` for the main data workflow
- Read `guides/queries-and-cursors.md` for AQL usage
- Read `guides/schema-and-operations.md` for collections, indexes, graphs, users, and databases