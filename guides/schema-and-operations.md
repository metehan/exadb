# Schema And Operations

Exadb also covers the practical operational side of working with ArangoDB.

## Collections

Create standard document collections:

```elixir
db_opts = [url: "localhost:8529", user: "root", pwd: "secret", db: "app"]

Exadb.Collection.new_collection("users", %{}, db_opts)
```

Create edge collections:

```elixir
Exadb.Collection.new_edge("follows", %{}, db_opts)
```

Rename and inspect collections:

```elixir
Exadb.Collection.rename("users", "accounts", db_opts)
Exadb.Collection.get("accounts", db_opts)
Exadb.Collection.get_all(db_opts)
```

## Indexes

Use `Exadb.Index` when a collection needs explicit indexes.

```elixir
dblink = Exadb.Api.db(nil, db_opts)

Exadb.Index.new(
  "users",
  %{
    "type" => "persistent",
    "fields" => ["email"],
    "unique" => true
  },
  dblink
)
```

You can also list or delete indexes:

```elixir
Exadb.Index.list("users", dblink)
Exadb.Index.clean_list("users", dblink)
```

## Graphs

Named graph setup stays compact.

```elixir
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

## Databases And Users

For tenant-style systems or operational setup flows:

```elixir
admin_opts = [url: "localhost:8529", user: "root", pwd: "secret"]

Exadb.Database.new_db_and_user("tenant_a", "tenant-secret", admin_opts)
Exadb.User.give_access("tenant_a", "tenant_a", Keyword.merge(admin_opts, level: "rw"))
```

Useful admin helpers include:

- `Exadb.Database.get_all/1`
- `Exadb.Database.user_dbs/2`
- `Exadb.Database.vaporize/2`
- `Exadb.User.get_all/1`
- `Exadb.User.get/2`
- `Exadb.User.replace/3`
- `Exadb.User.update/3`
- `Exadb.User.remove_access/3`
- `Exadb.User.vaporize/2`

## Copying structure and data

`Exadb.Manager` is useful when you need to copy collections, indexes, and optionally data between databases.

This is particularly helpful for:

- tenant bootstrapping
- template database setup
- internal migration scripts
- environment copy operations