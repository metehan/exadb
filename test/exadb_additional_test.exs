defmodule ExadbAdditionalTest do
  use ExUnit.Case, async: true

  import Exadb.TestHelpers

  defp put_default_env(bypass) do
    System.put_env("ADB_URL", "localhost:#{bypass.port}")
    System.put_env("ADB_USER", "root")
    System.put_env("ADB_PWD", "secret")
    System.put_env("ADB_DB", "example")
  end

  defp clear_default_env do
    System.delete_env("ADB_URL")
    System.delete_env("ADB_USER")
    System.delete_env("ADB_PWD")
    System.delete_env("ADB_DB")
  end

  describe "api and tool helpers" do
    test "reads defaults from environment and resolves dblink options" do
      System.put_env("ADB_URL", "envhost:9999")
      System.put_env("ADB_USER", "env_user")
      System.put_env("ADB_PWD", "env_pwd")
      System.put_env("ADB_DB", "env_db")

      on_exit(fn ->
        System.delete_env("ADB_URL")
        System.delete_env("ADB_USER")
        System.delete_env("ADB_PWD")
        System.delete_env("ADB_DB")
      end)

      assert Exadb.Api.url() == "http://env_user:env_pwd@envhost:9999"
      assert Exadb.Api.db() == "http://env_user:env_pwd@envhost:9999/_db/env_db/_api"

      assert %{dblink: "http://env_user:env_pwd@envhost:9999/_db/env_db/_api", col: "tmp"} =
               Exadb.Tools.dblink_opts([])

      assert %{dblink: "http://env_user:env_pwd@envhost:9999/_db/other/_api", col: "items"} =
               Exadb.Tools.dblink_opts(db: "other", col: "items")

      assert %{dblink: "http://custom/_db/example/_api", col: "tmp"} =
               Exadb.Tools.dblink_opts(dblink: "http://custom/_db/example/_api")
    end

    test "formats API errors and merges datasets" do
      assert Exadb.Tools.aql_cleaner(nil, "fallback") == "fallback"
      assert Exadb.Tools.aql_cleaner("RETURN 1", "fallback") == "fallback"

      assert {:error, "boom"} = Exadb.Tools.format_api_error(%{"errorMessage" => "boom"})
      assert {:ok, %{ok: true}} = Exadb.Tools.format_api_error(%{ok: true})
      assert {:error, "bad"} = Exadb.Tools.format_api_error(%{"errorMessage" => "bad"}, %{})

      assert {:ok, %{"_id" => "users/1", "email" => "a@example.com"}} =
               Exadb.Tools.format_api_error(
                 %{"_id" => "users/1"},
                 %{"email" => "a@example.com"}
               )

      assert {:ok,
              [
                %{"_id" => "users/1", "email" => "a@example.com"},
                %{"_id" => "users/2", "email" => "b@example.com"}
              ]} =
               Exadb.Tools.format_api_error(
                 [%{"_id" => "users/1"}, %{"_id" => "users/2"}],
                 [%{"email" => "a@example.com"}, %{"email" => "b@example.com"}]
               )

      assert {:ok, [%{"_id" => "users/1"}]} =
               Exadb.Tools.format_api_error(
                 [%{"_id" => "users/1"}],
                 [%{"email" => "a@example.com"}, %{"email" => "b@example.com"}]
               )
    end
  end

  describe "database and user request helpers" do
    test "covers remaining database endpoints" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "GET", "/_api/database", fn conn ->
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"result" => ["_system", "tenant"]}))
      end)

      assert {:ok, ["_system", "tenant"]} = Exadb.Database.get_all(admin_opts(bypass))

      Bypass.expect_once(bypass, "POST", "/_api/database", fn conn ->
        {body, conn} = read_json(conn)
        assert body == %{"name" => "tenant"}
        Plug.Conn.resp(conn, 201, Poison.encode!(%{"result" => true}))
      end)

      assert {:ok, %{"result" => true}} = Exadb.Database.new("tenant", admin_opts(bypass))

      Bypass.expect_once(bypass, "DELETE", "/_api/database/tenant", fn conn ->
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"result" => true}))
      end)

      assert {:ok, %{"result" => true}} = Exadb.Database.vaporize("tenant", admin_opts(bypass))
    end

    test "covers remaining user endpoints" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/_api/user", fn conn ->
        {body, conn} = read_json(conn)
        assert body == %{"user" => "alice", "passwd" => "pw", "active" => true}
        Plug.Conn.resp(conn, 201, Poison.encode!(%{"user" => "alice", "active" => true}))
      end)

      assert {:ok, %{"user" => "alice"}} =
               Exadb.User.new(
                 %{"user" => "alice", "passwd" => "pw", "active" => true},
                 admin_opts(bypass)
               )

      Bypass.expect_once(bypass, "GET", "/_api/user", fn conn ->
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"result" => [%{"user" => "alice"}]}))
      end)

      assert {:ok, %{"result" => [%{"user" => "alice"}]}} = Exadb.User.get_all(admin_opts(bypass))

      Bypass.expect_once(bypass, "GET", "/_api/user/alice", fn conn ->
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"user" => "alice", "active" => true}))
      end)

      assert {:ok, %{"user" => "alice"}} = Exadb.User.get("alice", admin_opts(bypass))

      Bypass.expect_once(bypass, "PATCH", "/_api/user/alice", fn conn ->
        {body, conn} = read_json(conn)
        assert body == %{"active" => false}
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"user" => "alice", "active" => false}))
      end)

      assert {:ok, %{"active" => false}} =
               Exadb.User.update("alice", %{"active" => false}, admin_opts(bypass))

      Bypass.expect_once(bypass, "DELETE", "/_api/user/alice/database/example", fn conn ->
        Plug.Conn.resp(conn, 202, Poison.encode!(%{"code" => 202, "error" => false}))
      end)

      assert {:ok, %{"code" => 202, "error" => false}} =
               Exadb.User.remove_access("alice", "example", admin_opts(bypass))

      Bypass.expect_once(bypass, "DELETE", "/_api/user/alice", fn conn ->
        Plug.Conn.resp(conn, 202, Poison.encode!(%{"code" => 202, "error" => false}))
      end)

      assert {:ok, %{"code" => 202, "error" => false}} =
               Exadb.User.vaporize("alice", admin_opts(bypass))
    end

    test "covers default-arity database and user wrappers via environment configuration" do
      bypass = Bypass.open()
      put_default_env(bypass)
      on_exit(&clear_default_env/0)

      Bypass.expect_once(bypass, "GET", "/_api/database", fn conn ->
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"result" => ["example"]}))
      end)

      assert {:ok, ["example"]} = Exadb.Database.get_all()

      Bypass.expect_once(bypass, "GET", "/_api/user/alice/database", fn conn ->
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"result" => %{"example" => "rw"}}))
      end)

      assert {:ok, %{"example" => "rw"}} = Exadb.Database.user_dbs("alice")

      Bypass.expect_once(bypass, "POST", "/_api/database", fn conn ->
        {body, conn} = read_json(conn)
        assert body == %{"name" => "tenant"}
        Plug.Conn.resp(conn, 201, Poison.encode!(%{"result" => true}))
      end)

      assert {:ok, %{"result" => true}} = Exadb.Database.new("tenant")

      Bypass.expect_once(bypass, "POST", "/_api/database", fn conn ->
        {body, conn} = read_json(conn)
        assert body["name"] == "tenant"
        assert [%{"username" => "tenant", "passwd" => "pw", "active" => true}] = body["users"]
        Plug.Conn.resp(conn, 201, Poison.encode!(%{"result" => true}))
      end)

      assert {:ok, %{"result" => true}} = Exadb.Database.new_db_and_user("tenant", "pw")

      Bypass.expect_once(bypass, "DELETE", "/_api/database/tenant", fn conn ->
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"result" => true}))
      end)

      assert {:ok, %{"result" => true}} = Exadb.Database.vaporize("tenant")

      Bypass.expect_once(bypass, "POST", "/_api/user", fn conn ->
        {body, conn} = read_json(conn)
        assert body == %{"user" => "alice", "passwd" => "pw"}
        Plug.Conn.resp(conn, 201, Poison.encode!(%{"user" => "alice"}))
      end)

      assert {:ok, %{"user" => "alice"}} = Exadb.User.new(%{"user" => "alice", "passwd" => "pw"})

      Bypass.expect_once(bypass, "GET", "/_api/user", fn conn ->
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"result" => [%{"user" => "alice"}]}))
      end)

      assert {:ok, %{"result" => [%{"user" => "alice"}]}} = Exadb.User.get_all()

      Bypass.expect_once(bypass, "GET", "/_api/user/alice", fn conn ->
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"user" => "alice"}))
      end)

      assert {:ok, %{"user" => "alice"}} = Exadb.User.get("alice")

      Bypass.expect_once(bypass, "PUT", "/_api/user/alice", fn conn ->
        {body, conn} = read_json(conn)
        assert body == %{"passwd" => "new-secret"}
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"user" => "alice"}))
      end)

      assert {:ok, %{"user" => "alice"}} =
               Exadb.User.replace("alice", %{"passwd" => "new-secret"})

      Bypass.expect_once(bypass, "PATCH", "/_api/user/alice", fn conn ->
        {body, conn} = read_json(conn)
        assert body == %{"active" => true}
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"user" => "alice"}))
      end)

      assert {:ok, %{"user" => "alice"}} = Exadb.User.update("alice", %{"active" => true})

      Bypass.expect_once(bypass, "PUT", "/_api/user/alice/database/example", fn conn ->
        {body, conn} = read_json(conn)
        assert body == %{"grant" => "rw"}
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"code" => 200, "error" => false}))
      end)

      assert {:ok, %{"code" => 200, "error" => false}} =
               Exadb.User.give_access("alice", "example")

      Bypass.expect_once(bypass, "DELETE", "/_api/user/alice/database/example", fn conn ->
        Plug.Conn.resp(conn, 202, Poison.encode!(%{"code" => 202, "error" => false}))
      end)

      assert {:ok, %{"code" => 202, "error" => false}} =
               Exadb.User.remove_access("alice", "example")

      Bypass.expect_once(bypass, "DELETE", "/_api/user/alice", fn conn ->
        Plug.Conn.resp(conn, 202, Poison.encode!(%{"code" => 202, "error" => false}))
      end)

      assert {:ok, %{"code" => 202, "error" => false}} = Exadb.User.vaporize("alice")
    end
  end

  describe "document helpers branch coverage" do
    test "covers fetch errors, update path, and vaporize edge cases" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "GET", "/_db/example/_api/document/users/404", fn conn ->
        Plug.Conn.resp(
          conn,
          404,
          Poison.encode!(%{"error" => true, "errorMessage" => "missing", "code" => 404})
        )
      end)

      assert {:error, "missing"} = Exadb.Doc.fetch("users/404", db_opts(bypass))

      Bypass.expect_once(bypass, "PATCH", "/_db/example/_api/document/users/1", fn conn ->
        {body, conn} = read_json(conn)
        assert body == %{"_id" => "users/1", "_rev" => "abc", "email" => "patched@example.com"}
        Plug.Conn.resp(conn, 202, Poison.encode!(%{"_id" => "users/1", "_rev" => "def"}))
      end)

      assert {:ok, %{"_rev" => "def", "email" => "patched@example.com"}} =
               Exadb.Doc.persist(
                 %{"_id" => "users/1", "_rev" => "abc", "email" => "patched@example.com"},
                 db_opts(bypass)
               )

      assert {:error, "no _id found in the record"} =
               Exadb.Doc.vaporize(%{"email" => "x"}, db_opts(bypass))

      Bypass.expect_once(bypass, "DELETE", "/_db/example/_api/document/users/404", fn conn ->
        Plug.Conn.resp(conn, 404, Poison.encode!(%{"error" => true, "code" => 404}))
      end)

      assert {:ok, :not_found} = Exadb.Doc.vaporize_by_id("users/404", db_opts(bypass))
    end

    test "covers get helpers and non-list push and pop cases" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/_db/example/_api/cursor", fn conn ->
        Plug.Conn.resp(
          conn,
          201,
          Poison.encode!(%{"result" => [%{"_id" => "users/1", "email" => "jane@example.com"}]})
        )
      end)

      assert %{"_id" => "users/1"} =
               Exadb.Doc.get_one(%{"email" => "jane@example.com"}, db_opts(bypass, col: "users"))

      Bypass.expect_once(bypass, "POST", "/_db/example/_api/cursor", fn conn ->
        Plug.Conn.resp(
          conn,
          201,
          Poison.encode!(%{"error" => true, "errorMessage" => "invalid query"})
        )
      end)

      assert {:error, "invalid query"} =
               Exadb.Doc.get(%{"email" => "broken"}, 10, db_opts(bypass, col: "users"))

      Bypass.expect_once(bypass, "GET", "/_db/example/_api/document/users/1", fn conn ->
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"name" => "Jane", "tags" => "oops"}))
      end)

      assert {:error, "tags is not a list"} =
               Exadb.Doc.push("users/1", "tags", "writer", db_opts(bypass))

      Bypass.expect_once(bypass, "GET", "/_db/example/_api/document/users/1", fn conn ->
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"name" => "Jane", "tags" => "oops"}))
      end)

      assert {:error, "tags is not a list"} =
               Exadb.Doc.pop("users/1", "tags", "writer", db_opts(bypass))

      Bypass.expect_once(bypass, "POST", "/_db/example/_api/cursor", fn conn ->
        Plug.Conn.resp(
          conn,
          201,
          Poison.encode!(%{"error" => true, "errorMessage" => "bad filter"})
        )
      end)

      assert {:error, "bad filter"} =
               Exadb.Doc.is_there?(
                 %{"email" => "jane@example.com"},
                 db_opts(bypass, col: "users")
               )
    end
  end

  describe "collection, query, and http helpers" do
    test "covers collection creation variants and typo compatibility" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/_db/example/_api/collection", fn conn ->
        {body, conn} = read_json(conn)

        assert body == %{
                 "name" => "items",
                 "type" => 2,
                 "keyOptions" => %{"type" => "autoincrement"}
               }

        Plug.Conn.resp(conn, 200, Poison.encode!(%{"name" => "items", "type" => 2}))
      end)

      assert {:ok, %{"name" => "items"}} =
               Exadb.Collection.new_collection("items", %{}, db_opts(bypass, inc: true))

      Bypass.expect_once(bypass, "POST", "/_db/example/_api/collection", fn conn ->
        {body, conn} = read_json(conn)
        assert body == %{"name" => "links", "type" => 3}
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"name" => "links", "type" => 3}))
      end)

      assert {:ok, %{"type" => 3}} = Exadb.Collection.new_edge("links", %{}, db_opts(bypass))

      Bypass.expect_once(bypass, "GET", "/_db/example/_api/collection", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Poison.encode!(%{
            "result" => [
              %{"name" => "a", "isSystem" => false},
              %{"name" => "_b", "isSystem" => true}
            ]
          })
        )
      end)

      assert {:ok, [%{"name" => "a"}]} =
               Exadb.Collection.get_all(db_opts(bypass, inclulde_system: true))
    end

    test "covers query cursor branches and stream halting" do
      bypass = Bypass.open()

      assert {:done, _} = Exadb.Query.cursor(%{"hasMore" => false}, db_opts(bypass))

      assert {:error, :boom} = Exadb.Query.cursor({:error, :boom}, db_opts(bypass))

      Bypass.expect_once(bypass, "POST", "/_db/example/_api/cursor", fn conn ->
        {body, conn} = read_json(conn)
        assert body == %{"query" => "RETURN 1"}
        Plug.Conn.resp(conn, 201, Poison.encode!(%{"result" => [1]}))
      end)

      assert {:ok, %{"result" => [1]}} = Exadb.Query.cursor("RETURN 1", db_opts(bypass))

      Bypass.expect_once(bypass, "POST", "/_db/example/_api/cursor", fn conn ->
        Plug.Conn.resp(conn, 404, Poison.encode!(%{"code" => 404}))
      end)

      assert {:error, :not_found} = Exadb.Query.cursor(%{"query" => "RETURN 1"}, db_opts(bypass))

      assert [] =
               Exadb.Query.cursor_stream(%{"hasMore" => false}, db_opts(bypass)) |> Enum.to_list()
    end

    test "covers default-arity collection, query, and document wrappers via environment configuration" do
      bypass = Bypass.open()
      put_default_env(bypass)
      on_exit(&clear_default_env/0)

      Bypass.expect_once(bypass, "GET", "/_db/example/_api/collection", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Poison.encode!(%{"result" => [%{"name" => "tmp", "isSystem" => false}]})
        )
      end)

      assert {:ok, [%{"name" => "tmp"}]} = Exadb.Collection.get_all()

      Bypass.expect_once(bypass, "GET", "/_db/example/_api/document/users/404", fn conn ->
        Plug.Conn.resp(conn, 404, Poison.encode!(%{"error" => true, "errorMessage" => "missing"}))
      end)

      assert {:error, "missing"} = Exadb.Doc.get_property("users/404", "email")

      Bypass.expect_once(bypass, "POST", "/_db/example/_api/cursor", fn conn ->
        {body, conn} = read_json(conn)
        assert body == %{"query" => "RETURN 1", "bindVars" => %{}}
        Plug.Conn.resp(conn, 201, Poison.encode!(%{"result" => [1]}))
      end)

      assert {:ok, [1]} = Exadb.Query.run("RETURN 1", %{})

      Bypass.expect_once(bypass, "POST", "/_db/example/_api/cursor", fn conn ->
        Plug.Conn.resp(conn, 201, Poison.encode!(%{"error" => true, "errorMessage" => "broken"}))
      end)

      assert {:error, "broken"} = Exadb.Query.run("RETURN 1", %{})

      Bypass.expect_once(bypass, "POST", "/_db/example/_api/cursor", fn conn ->
        Plug.Conn.resp(conn, 201, Poison.encode!(%{"unexpected" => true}))
      end)

      assert {:error, %{"unexpected" => true}} = Exadb.Query.run("RETURN 1", %{})
    end

    test "covers http wrapper methods and header merging" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "GET", "/json", fn conn ->
        assert ["application/json"] == Plug.Conn.get_req_header(conn, "accept")
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"ok" => true}))
      end)

      assert %{"ok" => true} = Exadb.Http.get!("http://localhost:#{bypass.port}/json")

      Bypass.expect_once(bypass, "POST", "/json", fn conn ->
        assert ["text/plain"] == Plug.Conn.get_req_header(conn, "content-type")
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body == "plain"
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"ok" => true}))
      end)

      assert %{"ok" => true} =
               Exadb.Http.post!(
                 "http://localhost:#{bypass.port}/json",
                 "plain",
                 [{"content-type", "text/plain"}]
               )

      Bypass.expect_once(bypass, "PUT", "/empty", fn conn ->
        Plug.Conn.resp(conn, 200, "")
      end)

      assert %{} = Exadb.Http.put!("http://localhost:#{bypass.port}/empty")

      Bypass.expect_once(bypass, "PATCH", "/json", fn conn ->
        {body, conn} = read_json(conn)
        assert body == %{"ok" => true}
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"patched" => true}))
      end)

      assert %{"patched" => true} =
               Exadb.Http.patch!("http://localhost:#{bypass.port}/json", %{"ok" => true})

      Bypass.expect_once(bypass, "DELETE", "/json", fn conn ->
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"deleted" => true}))
      end)

      assert %{"deleted" => true} = Exadb.Http.delete!("http://localhost:#{bypass.port}/json")
    end
  end
end
