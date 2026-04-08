defmodule Exadb.Tools do
  @moduledoc false

  def aql_cleaner(nil, default), do: default

  def aql_cleaner(sql, default) do
    regex =
      ~r/(?<filter>\((?:\(*(?:r\.[a-z-_]+|[0-9]+|true|false|@[a-z]+)+ (\=\=|\!\=|\<|\<\=|\>|\>\=|\=\~|\!\~|\&\&|\|\||AND|OR|IN|NOT IN|LIKE|NOT LIKE) (?:r\.[a-z-_]+|[0-9]+|true|false|@[a-z]+)+\)*(?: AND | OR )?)+\)(?: SORT(?: r\.[a-z-_]+ (?:ASC|DESC),?)+)*)(?: LIMIT \d+, \d+)*/

    case Regex.scan(regex, "(" <> sql <> ")", capture: :first) |> List.first() do
      [filter] -> filter
      _ -> default
    end
  end

  def format_api_error(%{"errorMessage" => error_message}) do
    {:error, error_message}
  end

  def format_api_error(any), do: {:ok, any}

  def format_api_error(%{"errorMessage" => error_message}, _dataset) do
    {:error, error_message}
  end

  def format_api_error(keyrevid, dataset) when is_map(dataset) and is_map(keyrevid) do
    {:ok, Map.merge(dataset, keyrevid)}
  end

  def format_api_error(keyrevid, dataset) when is_list(dataset) and is_list(keyrevid) do
    if length(dataset) == length(keyrevid) do
      {:ok,
       Enum.zip(dataset, keyrevid)
       |> Enum.map(fn {data, meta} -> Map.merge(data, meta) end)}
    else
      {:ok, keyrevid}
    end
  end

  def dblink_opts(opt) do
    dblink =
      case [Keyword.get(opt, :db), Keyword.get(opt, :dblink)] do
        [nil, nil] -> Exadb.Api.db(nil, opt)
        [nil, dblink] -> dblink
        [db, _dblink] -> Exadb.Api.db(db, opt)
      end

    col = Keyword.get(opt, :col, "tmp")
    %{dblink: dblink, col: col}
  end
end
