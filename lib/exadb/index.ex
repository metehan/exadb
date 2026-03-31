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
  def new(collection, opts, dblink)

  def new(collection, opts, dblink) when is_list(opts) do
    Enum.map(opts, &new(collection, &1, dblink))
  end

  def new(collection, opts, dblink) do
    Http.post!("#{dblink}/index?collection=#{collection}", opts)
    |> Tools.format_api_error()
  end

  @doc """
  Deletes an index by its full ArangoDB index identifier.
  """
  def delete(id, dblink) do
    Http.delete!("#{dblink}/index/#{id}")
  end

  @doc """
  Lists all indexes for a collection.
  """
  def list(collection, dblink) do
    Http.get!("#{dblink}/index?collection=#{collection}")
  end

  @doc """
  Returns a cleaned index list suitable for copying schema.

  Primary key and edge indexes are filtered out, and several server-managed
  metadata fields are removed.
  """
  def clean_list(collection, dblink) do
    list(collection, dblink)
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
  end
end
