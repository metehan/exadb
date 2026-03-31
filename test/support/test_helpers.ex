defmodule Exadb.TestHelpers do
  def db_opts(bypass, extra \\ []) do
    Keyword.merge(
      [url: "localhost:#{bypass.port}", user: "root", pwd: "secret", db: "example"],
      extra
    )
  end

  def admin_opts(bypass, extra \\ []) do
    Keyword.merge([url: "localhost:#{bypass.port}", user: "root", pwd: "secret"], extra)
  end

  def read_json(conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    {Poison.decode!(body), conn}
  end
end
