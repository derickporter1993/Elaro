import { describe, it, expect } from "vitest";
import { Command } from "commander";

// CLI smoke tests — verify the program structure is correct without
// executing side-effectful commands (org queries, file system writes, etc.)

describe("Elaro CLI program structure", () => {
  it("constructs a Commander program without throwing", async () => {
    // Dynamically import so module-level parse() is not called in test env
    const { statusCommand } = await import("./commands/status.js");
    const { scanCommand } = await import("./commands/scan.js");
    const { deployCommand } = await import("./commands/deploy.js");
    const { testCommand } = await import("./commands/test.js");
    const { orgCommand } = await import("./commands/org.js");
    const { configCommand } = await import("./commands/config.js");

    const program = new Command();
    program
      .name("elaro")
      .description("Elaro CLI test instance")
      .version("0.1.0", "-v, --version");

    program.addCommand(statusCommand);
    program.addCommand(scanCommand);
    program.addCommand(deployCommand);
    program.addCommand(testCommand);
    program.addCommand(orgCommand);
    program.addCommand(configCommand);

    expect(program.name()).toBe("elaro");
  });

  it("registers the expected subcommands", async () => {
    const { statusCommand } = await import("./commands/status.js");
    const { scanCommand } = await import("./commands/scan.js");
    const { deployCommand } = await import("./commands/deploy.js");
    const { testCommand } = await import("./commands/test.js");
    const { orgCommand } = await import("./commands/org.js");
    const { configCommand } = await import("./commands/config.js");

    const program = new Command();
    program.addCommand(statusCommand);
    program.addCommand(scanCommand);
    program.addCommand(deployCommand);
    program.addCommand(testCommand);
    program.addCommand(orgCommand);
    program.addCommand(configCommand);

    const commandNames = program.commands.map((c) => c.name());
    expect(commandNames).toContain("status");
    expect(commandNames).toContain("scan");
    expect(commandNames).toContain("deploy");
    expect(commandNames).toContain("test");
    expect(commandNames).toContain("org");
    expect(commandNames).toContain("config");
  });

  it("each command has a description", async () => {
    const { statusCommand } = await import("./commands/status.js");
    const { scanCommand } = await import("./commands/scan.js");
    const { deployCommand } = await import("./commands/deploy.js");

    expect(statusCommand.description()).toBeTruthy();
    expect(scanCommand.description()).toBeTruthy();
    expect(deployCommand.description()).toBeTruthy();
  });
});
