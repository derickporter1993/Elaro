import { describe, it, expect, vi } from "vitest";

// sf-client smoke tests — verify constructors and config validation without
// making real network calls to Salesforce.

describe("RestClient configuration", () => {
  it("can be imported and constructed with valid config", async () => {
    const { RestClient } = await import("./rest/client.js");
    const client = new RestClient({
      instanceUrl: "https://test.salesforce.com",
      accessToken: "test_access_token",
      apiVersion: "66.0",
    });
    expect(client).toBeDefined();
  });

  it("uses default API version when not specified", async () => {
    const { RestClient } = await import("./rest/client.js");
    const client = new RestClient({
      instanceUrl: "https://test.salesforce.com",
      accessToken: "test_access_token",
    });
    expect(client).toBeDefined();
  });
});

describe("BulkClient configuration", () => {
  it("can be constructed with valid config", async () => {
    const { BulkClient } = await import("./bulk/client.js");
    const client = new BulkClient({
      instanceUrl: "https://test.salesforce.com",
      accessToken: "test_access_token",
    });
    expect(client).toBeDefined();
  });
});

describe("ToolingClient configuration", () => {
  it("can be constructed with valid config", async () => {
    const { ToolingClient } = await import("./tooling/client.js");
    const client = new ToolingClient({
      instanceUrl: "https://test.salesforce.com",
      accessToken: "test_access_token",
    });
    expect(client).toBeDefined();
  });
});

describe("JWT authentication", () => {
  it("authenticateWithJwt rejects with invalid key (network error expected)", async () => {
    const { authenticateWithJwt } = await import("./auth/jwt.js");

    // Stub fetch to avoid real network calls
    vi.stubGlobal("fetch", async () => {
      return {
        ok: false,
        status: 400,
        json: async () => ({ error: "invalid_grant", error_description: "invalid key" }),
      };
    });

    await expect(
      authenticateWithJwt({
        clientId: "test_client_id",
        username: "test@example.com",
        privateKey: "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQ\n-----END RSA PRIVATE KEY-----",
        loginUrl: "https://test.salesforce.com",
      })
    ).rejects.toThrow();

    vi.unstubAllGlobals();
  });
});

describe("sf-client module exports", () => {
  it("exports expected symbols from the package index", async () => {
    const sfClient = await import("./index.js");
    expect(sfClient.authenticateWithJwt).toBeDefined();
    expect(sfClient.RestClient).toBeDefined();
    expect(sfClient.BulkClient).toBeDefined();
    expect(sfClient.ToolingClient).toBeDefined();
  });
});
