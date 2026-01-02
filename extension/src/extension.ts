import * as path from "path";
import * as fs from "fs";
import { workspace, ExtensionContext, window } from "vscode";
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  Executable,
} from "vscode-languageclient/node";

let client: LanguageClient;

export async function activate(context: ExtensionContext) {
  console.log("TSPT Extension: Starting activation...");

  const projectRoot = path.join(context.extensionPath, "..");
  const serverPath = path.join(projectRoot, "bin", "server.exe");

  console.log(`TSPT Extension: Looking for server at: ${serverPath}`);

  if (!fs.existsSync(serverPath)) {
    const errorMsg = `TSPT Server not found at: ${serverPath}. Did you run 'dart compile exe bin/lsp_server.dart -o bin/server.exe'?`;
    console.error(errorMsg);
    window.showErrorMessage(errorMsg);
    return;
  }

  const run: Executable = {
    command: serverPath,
    args: [],
    options: {
      cwd: projectRoot,
    },
  };

  const serverOptions: ServerOptions = {
    run: run,
    debug: run,
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ scheme: "file", language: "tspt" }],
    outputChannelName: "Typesetting LSP",
  };

  client = new LanguageClient(
    "tsptLsp",
    "Typesetting Language Server",
    serverOptions,
    clientOptions
  );

  try {
    console.log("TSPT Extension: Starting client...");
    await client.start();
    console.log("TSPT Extension: Client started successfully.");
  } catch (e) {
    console.error("TSPT Extension: Failed to start client:", e);
    window.showErrorMessage(
      "TSPT Extension failed to start. Check Debug Console for details."
    );
  }
}

export function deactivate(): Thenable<void> | undefined {
  return client ? client.stop() : undefined;
}
