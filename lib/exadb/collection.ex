defmodule Exadb.Collection do
  @moduledoc """
  Collection helpers for document and edge collections.

  Use this module for schema-level collection operations such as creating,
  renaming, listing, and deleting collections.

  It supports both standard document collections and edge collections.
  """

  alias Exadb.Http
  alias Exadb.Tools

  @doc """
  Creates a document collection.
  """
  def new_collection(name, arango_opts, opt \\ []) do
    new(name, 2, arango_opts, opt)
  end

  @doc """
  Creates an edge collection.
  """
  def new_edge(name, arango_opts, opt \\ []) do
    new(name, 3, arango_opts, opt)
  end

  @doc """
  Creates a collection of the given ArangoDB type.

  Set `opt[:inc]` to create an autoincrement key generator.
  """
  def new(name, type, arango_opts, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    arango_opts =
      if opt[:inc] do
        Map.merge(arango_opts, %{"keyOptions" => %{"type" => "autoincrement"}})
      else
        arango_opts
      end

    Http.post!("#{dblink}/collection", Map.merge(%{name: name, type: type}, arango_opts))
    |> Tools.format_api_error()
  end

  @doc """
  Deletes a collection.
  """
  def delete(name, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)
    Http.delete!("#{dblink}/collection/#{name}")
  end

  @doc """
  Renames a collection.
  """
  def rename(old_name, new_name, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    Http.put!("#{dblink}/collection/#{old_name}/rename", %{name: new_name})
    |> Tools.format_api_error()
  end

  @doc """
  Lists collections in the current database.

  By default system collections are filtered out. Pass `include_system: true`
  to keep them in the result. Pass `expanded: true` to return collection
  properties instead of the compact listing.
  """
  def get_all(opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)
    include_system = Keyword.get(opt, :include_system, Keyword.get(opt, :inclulde_system, false))

    all =
      Http.get!("#{dblink}/collection")
      |> Map.get("result")

    all =
      if include_system do
        all
      else
        Enum.filter(all, fn item -> item["isSystem"] == false end)
      end

    if opt[:expanded] do
      Enum.map(all, fn item -> get(item["name"], opt) end)
    else
      all
    end
  end

  @doc """
  Returns collection properties for a specific collection.
  """
  def get(collection, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)
    Http.get!("#{dblink}/collection/#{collection}/properties")
  end

  @doc """
  Checks whether a collection exists.
  """
  def is_there?(name, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)
    api_url = "#{dblink}/collection/#{name}"

    case HTTPoison.get(api_url, [], hackney: [pool: :arango_db]) do
      {:ok, %HTTPoison.Response{status_code: 200}} -> true
      {:ok, %HTTPoison.Response{status_code: 404}} -> false
      {:error, %HTTPoison.Error{reason: reason}} -> {:error, reason}
    end
  end
end
