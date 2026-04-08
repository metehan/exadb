defmodule Exadb.Index do
  @moduledoc """
  Helpers for ArangoDB index endpoints.

  Use this module to create, list, clean, and delete collection indexes.

  It works well alongside `Exadb.Collection` when bootstrapping or maintaining
  database schema in application setup code, migrations, or admin tooling.
  """

  alias Exadb.Http
  alias Exadb.Tools

  @doc """
  Creates one or more indexes for a collection.

  Pass either a single index definition map or a list of index definition maps.
  """
  def new(collection, opts, opt \\ [])

  def new(collection, opts, opt) when is_list(opts) do
    Enum.map(opts, &new(collection, &1, opt))
  end

  def new(collection, opts, opt) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    Http.post!("#{dblink}/index?collection=#{collection}", opts)
    |> Tools.format_api_error()
  end

  @doc """
  Deletes an index by its full ArangoDB index identifier.

  Use `delete` for schema-level objects (collections, indexes, graphs).
  Use `vaporize` for runtime data records (documents).
  """
  def delete(id, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    Http.delete!("#{dblink}/index/#{id}")
    |> Tools.format_api_error()
  end

  @doc """
  Lists all indexes for a collection.
  """
  def list(collection, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    Http.get!("#{dblink}/index?collection=#{collection}")
    |> Tools.format_api_error()
  end

  @doc """
  Returns a cleaned index list suitable for copying schema.

  Primary key and edge indexes are filtered out, and several server-managed
  metadata fields are removed.

  Returns `{:ok, list}` on success.
  """
  def clean_list(collection, opt \\ []) do
    case list(collection, opt) do
      {:ok, result} ->
        indexes =
          result
          |> Map.get("indexes")
          |> Enum.reject(&(&1["fields"] == ["_key"]))
          |> Enum.reject(&(&1["type"] == "edge"))
          |> Enum.map(
            &Map.drop(&1, [
              "id",
              "selectivityEstimate",
              "bestIndexedLevel",
              "maxNumCoverCells",
              "worstIndexedLevel"
            ])
          )

        {:ok, indexes}

      {:error, _} = err ->
        err
    end
  end
end
