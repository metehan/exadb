defmodule Exadb.Doc do
  @moduledoc """
  Document helpers built on top of ArangoDB's document and cursor endpoints.

  This is the main module for day-to-day Exadb usage.

  The typical workflow is:

  1. fetch a document
  2. edit the returned map
  3. persist it back with `persist/2`

  `persist/2` is intentionally smart:

  - new plain maps are inserted
  - fetched documents that still contain ArangoDB metadata are updated

  This keeps application code simple and lets you work with ordinary maps
  instead of custom structs.
  """

  alias Exadb.Http
  alias Exadb.Tools

  @doc """
  Returns a single document by `_id`.

  Returns `{:ok, document}` on success or `{:error, message}` when the document
  is not found or ArangoDB reports an error.
  """
  @spec fetch(binary(), keyword()) :: {:ok, map()} | {:error, binary()}
  def fetch(doc, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    case Http.get!("#{dblink}/document/#{doc}") do
      %{"error" => true, "errorMessage" => message} -> {:error, message}
      record -> {:ok, record}
    end
  end

  @doc """
  Fetches multiple documents by `_id`.

  Returns `{:ok, list}` on success or `{:error, message}` on failure.
  """
  @spec fetch_multi(list(), keyword()) :: {:ok, list()} | {:error, binary()}
  def fetch_multi(doc_ids, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    case Http.post!("#{dblink}/cursor", %{
           query: "RETURN DOCUMENT(@list)",
           bindVars: %{list: doc_ids}
         }) do
      %{"error" => true, "errorMessage" => message} -> {:error, message}
      %{"result" => list} -> {:ok, list}
      unknown -> {:error, unknown}
    end
  end

  @doc """
  Persists a map.

  Existing documents are patched, new documents are inserted.

  A map containing `_id` and `_rev` is treated as an update target. A plain map
  without ArangoDB metadata is treated as a new document.
  """
  def persist(dataset, opt \\ []) when is_map(dataset) do
    case dataset do
      %{"_rev" => _rev, "_id" => id} -> persist_via_update(dataset, id, opt)
      _ -> persist_via_create(dataset, opt)
    end
  end

  @doc """
  Persists a list of maps in one request.

  This is useful for bulk insert/update flows where you already have a batch of
  documents ready to write.
  """
  def persist_multi(datasets, opt \\ []) when is_list(datasets) do
    %{dblink: dblink, col: col} = Tools.dblink_opts(opt)

    Http.post!(
      "#{dblink}/document/#{col}?silent=false&overwrite=true&overwriteMode=update&ignoreRevs=false",
      datasets
    )
    |> Tools.format_api_error(datasets)
  end

  @doc """
  Removes ArangoDB metadata and inserts a new document into the same collection.
  """
  def persist_new(dataset, opt \\ []) when is_map(dataset) do
    %{dblink: dblink} = Tools.dblink_opts(opt)
    [col, _key] = String.split(dataset["_id"], "/")

    dataset
    |> Map.delete("_id")
    |> Map.delete("_key")
    |> Map.delete("_rev")
    |> persist(dblink: dblink, col: col)
  end

  @doc """
  Returns the value of a single property from a document.

  Returns `nil` when the property is absent. Propagates `{:error, message}` if
  the document cannot be fetched.
  """
  def get_property(document_id, property, opt \\ []) do
    case fetch(document_id, opt) do
      {:error, _} = err -> err
      {:ok, doc} -> doc[property]
    end
  end

  @doc """
  Appends a value to a list property of a document, avoiding duplicates.

  Returns `{:error, message}` if the property is not a list or the fetch fails.
  """
  def push(document_id, property, value, opt \\ []) do
    new_list = List.flatten([value])

    case get_property(document_id, property, opt) do
      {:error, _} = err ->
        err

      current ->
        new_value =
          case current do
            v when is_list(v) -> v ++ (new_list -- v)
            nil -> new_list
            _ -> false
          end

        if is_list(new_value) do
          update_property(document_id, property, new_value, opt)
        else
          {:error, "#{property} is not a list"}
        end
    end
  end

  @doc """
  Removes a value from a list property of a document.

  Returns `{:error, message}` if the property is not a list or the fetch fails.
  """
  def pop(document_id, property, value, opt \\ []) do
    case get_property(document_id, property, opt) do
      {:error, _} = err ->
        err

      current when is_list(current) ->
        update_property(document_id, property, current -- [value], opt)

      _ ->
        {:error, "#{property} is not a list"}
    end
  end

  @doc """
  Updates a single property of a document.
  """
  def update_property(document_id, property, value, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    Http.patch!("#{dblink}/document/#{document_id}", %{property => value})
    |> Tools.format_api_error()
  end

  @doc """
  Sets a boolean property to `true`.
  """
  def switch_on(document_id, property, opt \\ []) do
    update_property(document_id, property, true, opt)
  end

  @doc """
  Sets a boolean property to `false`.
  """
  def switch_off(document_id, property, opt \\ []) do
    update_property(document_id, property, false, opt)
  end

  @doc """
  Returns the first matching document for a simple field-value lookup.

  Returns `nil` when no document matches. Propagates `{:error, message}` on
  AQL or network failures.
  """
  def get_one(vars_values, opt \\ []) when is_map(vars_values) do
    case get(vars_values, 1, opt) do
      {:error, _} = err -> err
      {:ok, [first | _]} -> first
      {:ok, []} -> nil
    end
  end

  @doc """
  Returns documents matching a simple field-value lookup.

  This helper builds a basic AQL filter from the provided map and is a good fit
  when you want a quick lookup without writing the query manually.

  Returns `{:ok, list}` on success (list may be empty).
  """
  @spec get(map(), pos_integer(), keyword()) :: {:ok, list()} | {:error, binary()}
  def get(vars_values, limit \\ 1000, opt \\ []) do
    %{dblink: dblink, col: col} = Tools.dblink_opts(opt)

    filters =
      vars_values
      |> Map.to_list()
      |> Enum.map(fn {var, _value} -> "doc.#{var} == @#{var}" end)
      |> Enum.join(" AND ")

    try do
      case Http.post!("#{dblink}/cursor", %{
             query: "FOR doc IN #{col} FILTER #{filters} LIMIT #{limit} RETURN doc",
             bindVars: vars_values
           }) do
        %{"error" => true, "errorMessage" => message} -> {:error, message}
        %{"result" => list} -> {:ok, list}
        unknown -> {:error, unknown}
      end
    rescue
      error in HTTPoison.Error -> {:error, error}
      other -> {:error, other}
    end
  end

  @spec vaporize(map(), keyword()) :: {:error, binary()} | {:ok, binary() | :not_found}
  def vaporize(record, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    case record do
      %{"_id" => id} -> vaporize_by_id(id, dblink: dblink)
      _ -> {:error, "no _id found in the record"}
    end
  end

  @spec vaporize_by_id(binary(), keyword()) :: {:error, binary()} | {:ok, binary() | :not_found}
  def vaporize_by_id(id, opt \\ []) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    case Http.delete!("#{dblink}/document/#{id}") do
      %{"code" => 404} -> {:ok, :not_found}
      %{"error" => true, "errorMessage" => message} -> {:error, message}
      %{"_id" => result_id} -> {:ok, result_id}
      unknown -> {:error, unknown}
    end
  end

  @doc """
  Checks whether at least one matching document exists.
  """
  @spec is_there?(map(), keyword()) :: boolean() | {:error, any()}
  def is_there?(vars_values, opt) do
    %{dblink: dblink, col: col} = Tools.dblink_opts(opt)

    filters =
      vars_values
      |> Map.to_list()
      |> Enum.map(fn {var, _value} -> "doc.#{var} == @#{var}" end)
      |> Enum.join(" AND ")

    case Http.post!("#{dblink}/cursor", %{
           query: "FOR doc IN #{col} FILTER #{filters} LIMIT 1 RETURN doc._id",
           bindVars: vars_values
         }) do
      %{"error" => true, "errorMessage" => message} -> {:error, message}
      %{"result" => [_id]} -> true
      %{"result" => []} -> false
      unknown -> {:error, unknown}
    end
  end

  defp persist_via_create(dataset, opt) do
    %{dblink: dblink, col: col} = Tools.dblink_opts(opt)

    Http.post!("#{dblink}/document/#{col}", dataset)
    |> Tools.format_api_error(dataset)
  end

  defp persist_via_update(dataset, id, opt) do
    %{dblink: dblink} = Tools.dblink_opts(opt)

    Http.patch!("#{dblink}/document/#{id}", dataset)
    |> Tools.format_api_error(dataset)
  end
end
