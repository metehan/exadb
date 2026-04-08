defmodule Exadb.Graph do
  @moduledoc """
  Helpers for ArangoDB graph endpoints.

  Use this module to manage named graphs backed by existing vertex and edge
  collections.

  The term `delete` is used here (rather than `vaporize`) because a named graph
  is a schema-level object. `vaporize` is reserved for runtime data records
  such as documents.
  """

  alias Exadb.Http
  alias Exadb.Tools

  @doc """
  Creates a named graph.
  """
  def new(name, edge_definitions, orphan_collections, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    Http.post!("#{dblink}/gharial", %{
      name: name,
      edgeDefinitions: edge_definitions,
      orphanCollections: orphan_collections
    })
    |> Tools.format_api_error()
  end

  @doc """
  Deletes a named graph.
  """
  def delete(name, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    Http.delete!("#{dblink}/gharial/#{name}")
    |> Tools.format_api_error()
  end

  @doc """
  Lists named graphs.
  """
  def get_all(opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    Http.get!("#{dblink}/gharial")
    |> Tools.format_api_error()
  end
end
