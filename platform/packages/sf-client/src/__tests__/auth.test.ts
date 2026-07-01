import { describe, it, expect } from "vitest";

import { validateJwtConfig, AuthenticationError } from "../auth/jwt";
import { buildAuthorizationUrl, OAuthError } from "../auth/oauth";

const VALID_PEM = "-----BEGIN PRIVATE KEY-----\nMIIfake\n-----END PRIVATE KEY-----";

describe("validateJwtConfig", () => {
  it("returns no errors for a complete, valid config", () => {
    const errors = validateJwtConfig({
      clientId: "abc",
      username: "user@example.com",
      privateKey: VALID_PEM,
    });
    expect(errors).toEqual([]);
  });

  it("flags a missing clientId", () => {
    const errors = validateJwtConfig({ clientId: "", username: "u", privateKey: VALID_PEM });
    expect(errors).toContain("clientId is required");
  });

  it("flags a missing username", () => {
    const errors = validateJwtConfig({ clientId: "a", username: "", privateKey: VALID_PEM });
    expect(errors).toContain("username is required");
  });

  it("flags a missing private key", () => {
    const errors = validateJwtConfig({ clientId: "a", username: "u", privateKey: "" });
    expect(errors).toContain("privateKey is required");
  });

  it("flags a private key that is not PEM-formatted", () => {
    const errors = validateJwtConfig({ clientId: "a", username: "u", privateKey: "not-a-key" });
    expect(errors).toContain("privateKey must be a valid PEM-formatted RSA private key");
  });

  it("accumulates multiple errors at once", () => {
    const errors = validateJwtConfig({ clientId: "", username: "", privateKey: "" });
    expect(errors).toHaveLength(3);
  });
});

describe("buildAuthorizationUrl", () => {
  it("builds a URL with defaults", () => {
    const url = new URL(
      buildAuthorizationUrl({
        clientId: "myclient",
        clientSecret: "secret",
        redirectUri: "https://app.example.com/callback",
      })
    );

    expect(url.origin + url.pathname).toBe(
      "https://login.salesforce.com/services/oauth2/authorize"
    );
    expect(url.searchParams.get("response_type")).toBe("code");
    expect(url.searchParams.get("client_id")).toBe("myclient");
    expect(url.searchParams.get("redirect_uri")).toBe("https://app.example.com/callback");
    expect(url.searchParams.get("scope")).toBe("api refresh_token full");
  });

  it("honors custom scopes, login URL, and state", () => {
    const url = new URL(
      buildAuthorizationUrl(
        {
          clientId: "c",
          clientSecret: "s",
          redirectUri: "https://cb",
          loginUrl: "https://test.salesforce.com",
          scopes: ["api", "web"],
        },
        "xyz-state"
      )
    );

    expect(url.origin).toBe("https://test.salesforce.com");
    expect(url.searchParams.get("scope")).toBe("api web");
    expect(url.searchParams.get("state")).toBe("xyz-state");
  });

  it("omits state when it is not provided", () => {
    const url = new URL(
      buildAuthorizationUrl({ clientId: "c", clientSecret: "s", redirectUri: "https://cb" })
    );
    expect(url.searchParams.has("state")).toBe(false);
  });
});

describe("auth error types", () => {
  it("expose named error classes", () => {
    expect(new AuthenticationError("boom").name).toBe("AuthenticationError");
    expect(new OAuthError("boom").name).toBe("OAuthError");
    expect(new AuthenticationError("boom")).toBeInstanceOf(Error);
  });
});
