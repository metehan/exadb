defmodule ExadbTest do
  use ExUnit.Case, async: true

  import Exadb.TestHelpers

  describe "api builders" do
    test "builds root and db urls from explicit opts" do
      opts = [url: "localhost:8529", user: "root", pwd: "secret", db: "sample"]

      assert Exadb.Api.url(opts) == "http://root:secret@localhost:8529"
      assert Exadb.Api.root(opts) == "http://root:secret@localhost:8529/_api"
      assert Exadb.Api.db(nil, opts) == "http://root:secret@localhost:8529/_db/sample/_api"
      assert Exadb.Api.db("other", opts) == "http://root:secret@localhost:8529/_db/other/_api"
    end
  end

  describe "database helpers" do
    test "creates a database and user with the expected payload" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/_api/database", fn conn ->
        {body, conn} = read_json(conn)

        assert body == %{
                 "name" => "tenant_a",
                 "users" => [
                   %{"active" => true, "passwd" => "pw123", "username" => "tenant_a"}
                 ]
               }

        Plug.Conn.resp(conn, 201, Poison.encode!(%{"result" => true}))
      end)

      assert {:ok, %{"result" => true}} =
               Exadb.Database.new_db_and_user("tenant_a", "pw123", admin_opts(bypass))
    end

    test "lists accessible databases through the corrected user endpoint" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "GET", "/_api/user/alice/database", fn conn ->
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"result" => %{"example" => "rw"}}))
      end)

      assert {:ok, %{"example" => "rw"}} = Exadb.Database.user_dbs("alice", admin_opts(bypass))
    end
  end

  describe "document helpers" do
    test "persist inserts new documents and merges Arango metadata" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/_db/example/_api/document/users", fn conn ->
        {body, conn} = read_json(conn)
        assert body == %{"email" => "jane@example.com"}

        Plug.Conn.resp(
          conn,
          201,
          Poison.encode!(%{"_id" => "users/123", "_key" => "123", "_rev" => "abc"})
        )
      end)

      assert {:ok, %{"_id" => "users/123", "email" => "jane@example.com"}} =
               Exadb.Doc.persist(%{"email" => "jane@example.com"}, db_opts(bypass, col: "users"))
    end

    test "persist_new strips _id, _key, and _rev before insert" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/_db/example/_api/document/users", fn conn ->
        {body, conn} = read_json(conn)
        refute Map.has_key?(body, "_id")
        refute Map.has_key?(body, "_key")
        refute Map.has_key?(body, "_rev")
        assert body == %{"email" => "jane@example.com"}

        Plug.Conn.resp(
          conn,
          201,
          Poison.encode!(%{"_id" => "users/456", "_key" => "456", "_rev" => "def"})
        )
      end)

      record = %{
        "_id" => "users/123",
        "_key" => "123",
        "_rev" => "abc",
        "email" => "jane@example.com"
      }

      assert {:ok, %{"_id" => "users/456", "email" => "jane@example.com"}} =
               Exadb.Doc.persist_new(record, db_opts(bypass))
    end

    test "fetch_multi returns the full result set" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/_db/example/_api/cursor", fn conn ->
        {body, conn} = read_json(conn)
        assert body["query"] == "RETURN DOCUMENT(@list)"
        assert body["bindVars"] == %{"list" => ["users/1", "users/2"]}

        Plug.Conn.resp(
          conn,
          201,
          Poison.encode!(%{"result" => [%{"_id" => "users/1"}, %{"_id" => "users/2"}]})
        )
      end)

      assert {:ok, [%{"_id" => "users/1"}, %{"_id" => "users/2"}]} =
               Exadb.Doc.fetch_multi(["users/1", "users/2"], db_opts(bypass))
    end
  end

  describe "collection helpers" do
    test "filters system collections by default and supports include_system" do
      bypass = Bypass.open()

      responder = fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Poison.encode!(%{
            "result" => [
              %{"name" => "users", "isSystem" => false},
              %{"name" => "_users", "isSystem" => true}
            ]
          })
        )
      end

      Bypass.expect_once(bypass, "GET", "/_db/example/_api/collection", responder)
      assert {:ok, [%{"name" => "users"}]} = Exadb.Collection.get_all(db_opts(bypass))

      Bypass.expect_once(bypass, "GET", "/_db/example/_api/collection", responder)

      assert {:ok, [%{"name" => "users"}, %{"name" => "_users"}]} =
               Exadb.Collection.get_all(db_opts(bypass, include_system: true))
    end
  end

  describe "query helpers" do
    test "returns not_found on empty result" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/_db/example/_api/cursor", fn conn ->
        Plug.Conn.resp(conn, 201, Poison.encode!(%{"result" => []}))
      end)

      assert {:ok, []} = Exadb.Query.run("FOR doc IN users RETURN doc", %{}, db_opts(bypass))
    end
  end

  describe "user helpers" do
    test "give_access uses the corrected database permission path and JSON body" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "PUT", "/_api/user/alice/database/example", fn conn ->
        {body, conn} = read_json(conn)
        assert body == %{"grant" => "ro"}
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"result" => true}))
      end)

      assert {:ok, %{"result" => true}} =
               Exadb.User.give_access("alice", "example", admin_opts(bypass, level: "ro"))
    end

    test "replace sends the provided attributes to the corrected user endpoint" do
      bypass = Bypass.open()

      Bypass.expect_once(bypass, "PUT", "/_api/user/alice", fn conn ->
        {body, conn} = read_json(conn)
        assert body == %{"active" => true, "passwd" => "new-secret"}
        Plug.Conn.resp(conn, 200, Poison.encode!(%{"user" => "alice"}))
      end)

      assert {:ok, %{"user" => "alice"}} =
               Exadb.User.replace(
                 "alice",
                 %{"passwd" => "new-secret", "active" => true},
                 admin_opts(bypass)
               )
    end
  end
end
