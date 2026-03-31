Code.require_file("support/test_helpers.ex", __DIR__)
Code.require_file("support/integration_test_helpers.ex", __DIR__)

exclude =
  if Exadb.IntegrationTestHelpers.integration_enabled?() do
    []
  else
    [integration: true]
  end

ExUnit.start(exclude: exclude)
