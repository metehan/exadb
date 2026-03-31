# Document Workflow

The main reason to use Exadb is the document workflow.

The pattern is simple:

1. fetch a document
2. edit the map
3. persist the map

## Why this workflow works well

Exadb returns plain maps.

That keeps application code close to the database shape and makes small changes cheap.

```elixir
opts = [url: "localhost:8529", user: "root", pwd: "secret", db: "app", col: "users"]

user = Exadb.Doc.fetch("users/123", opts)

updated_user =
  user
  |> Map.put("display_name", "Jane Doe")
  |> Map.update("tags", ["customer"], fn tags -> Enum.uniq(tags ++ ["customer"]) end)
  |> Exadb.Doc.persist(opts)
```

## Smart persist

`Exadb.Doc.persist/2` decides between insert and update based on the contents of the map.

- New plain map: insert
- Existing document map with `_id` and `_rev`: update

This removes a lot of branching from application code.

## Creating fresh copies

If you want to reuse a fetched document as the basis for a new record, use `persist_new/2`.

```elixir
copy =
  Exadb.Doc.fetch("users/123", opts)
  |> Map.put("email", "new@example.com")
  |> Exadb.Doc.persist_new(opts)
```

`persist_new/2` strips `_id`, `_key`, and `_rev` before inserting.

## Working with targeted lookups

Use `get/3` and `get_one/2` when you want simple field-based lookups without writing AQL manually.

```elixir
Exadb.Doc.get(%{"active" => true}, 100, opts)
Exadb.Doc.get_one(%{"email" => "jane@example.com"}, opts)
```

## List properties

For document fields that are lists, `push/4` and `pop/4` keep updates concise.

```elixir
Exadb.Doc.push("users/123", "roles", "admin", opts)
Exadb.Doc.pop("users/123", "roles", "guest", opts)
```

## Single-field updates

When you only want to change one property, use `update_property/4`, `switch_on/3`, or `switch_off/3`.

```elixir
Exadb.Doc.update_property("users/123", "display_name", "Jane Doe", opts)
Exadb.Doc.switch_on("users/123", "active", opts)
Exadb.Doc.switch_off("users/123", "suspended", opts)
```

## Existence checks and deletion

```elixir
Exadb.Doc.is_there?(%{"email" => "jane@example.com"}, opts)
Exadb.Doc.vaporize_by_id("users/123", opts)
```

Use these helpers when you want straightforward CRUD behavior without dropping into AQL.