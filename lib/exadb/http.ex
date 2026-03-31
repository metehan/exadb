defmodule Exadb.Http do
  @moduledoc """
  Small JSON wrapper around `HTTPoison` used by the higher-level modules.

  This module centralizes the low-level details of:

  - JSON encoding and decoding
  - default request headers
  - shared Hackney pool options

  Most application code should use `Exadb.Doc`, `Exadb.Query`, `Exadb.Collection`,
  and the other high-level modules directly.
  """

  @default_headers [
    {"content-type", "application/json"},
    {"accept", "application/json"}
  ]

  @default_options [hackney: [pool: :arango_db]]

  @doc """
  Sends a `GET` request and decodes the JSON response body.
  """
  def get!(url, headers \\ [], options \\ []) do
    HTTPoison.get!(url, merge_headers(headers), merge_options(options)).body
    |> decode!()
  end

  @doc """
  Sends a `POST` request and decodes the JSON response body.
  """
  def post!(url, body, headers \\ [], options \\ []) do
    HTTPoison.post!(url, encode_body(body), merge_headers(headers), merge_options(options)).body
    |> decode!()
  end

  @doc """
  Sends a `PUT` request and decodes the JSON response body.
  """
  def put!(url, body \\ "", headers \\ [], options \\ []) do
    HTTPoison.put!(url, encode_body(body), merge_headers(headers), merge_options(options)).body
    |> decode!()
  end

  @doc """
  Sends a `PATCH` request and decodes the JSON response body.
  """
  def patch!(url, body, headers \\ [], options \\ []) do
    HTTPoison.patch!(url, encode_body(body), merge_headers(headers), merge_options(options)).body
    |> decode!()
  end

  @doc """
  Sends a `DELETE` request and decodes the JSON response body.
  """
  def delete!(url, headers \\ [], options \\ []) do
    HTTPoison.delete!(url, merge_headers(headers), merge_options(options)).body
    |> decode!()
  end

  defp encode_body(body) when is_binary(body), do: body
  defp encode_body(body), do: Poison.encode!(body)

  defp decode!(body) when body in [nil, ""], do: %{}
  defp decode!(body), do: Poison.decode!(body)

  defp merge_headers(headers) do
    existing =
      MapSet.new(Enum.map(headers, fn {key, _value} -> String.downcase(to_string(key)) end))

    Enum.reject(@default_headers, fn {key, _value} -> MapSet.member?(existing, key) end) ++
      headers
  end

  defp merge_options(options) do
    Keyword.merge(@default_options, options, fn
      :hackney, default, supplied -> Keyword.merge(default, supplied)
      _key, _default, supplied -> supplied
    end)
  end
end
