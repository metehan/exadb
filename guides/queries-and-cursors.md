# Queries And Cursors

Use `Exadb.Query` when the shape of the work is better expressed in AQL than in direct document helpers.

## Simple AQL execution

```elixir
opts = [url: "localhost:8529", user: "root", pwd: "secret", db: "app"]

{:ok, users} = Exadb.Query.run(
  "FOR user IN users FILTER user.email == @email RETURN user",
  %{email: "jane@example.com"},
  opts
)
```

This is a good fit when you already know the query you want and just need a small helper around bind variables and decoded JSON responses.

## Cursor usage

For larger result sets or multi-page reads, use `cursor/2`.

```elixir
{:ok, first_page} =
  Exadb.Query.cursor(
    %{
      query: "FOR user IN users SORT user.email RETURN user",
      batchSize: 100
    },
    opts
  )
```

If ArangoDB returns a cursor ID and more results are available, passing that result back
to `cursor/2` fetches the next page. When no more pages remain, `cursor/2` returns
`{:done, last_page}` instead of `{:ok, page}`.

## Streaming cursor pages

If you want to process pages one by one, use `cursor_stream/2`.

```elixir
Exadb.Query.cursor_stream(
  %{
    query: "FOR user IN users SORT user.email RETURN user",
    batchSize: 100
  },
  opts
)
|> Enum.each(fn page ->
  IO.inspect(page["result"])
end)
```

Each element emitted by the stream is the raw cursor response map. The stream halts
automatically when the cursor is exhausted or an error occurs.

This is especially useful for:

- exports
- background processing
- copying data between databases
- migration tasks

## When to use queries vs document helpers

Use `Exadb.Doc` when you are working with a single collection and simple lookup/update flows.

Use `Exadb.Query` when you need:

- joins across collections
- aggregation
- custom filtering
- explicit sorting and paging
- multi-step AQL logic