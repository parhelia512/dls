/*
    HIGHLY inspired by the wonderful rust-analyzer, and contains modification of code from rust-analyzer vscode extension.
*/

import * as vscode from 'vscode';
import * as path from "path";
import * as os from "os";
import { promises as fs, PathLike, constants, writeFileSync } from "fs";

var AdmZip = require('adm-zip');

import {
    InitializeParams,
    LanguageClient,
    LanguageClientOptions,
    ServerOptions
} from 'vscode-languageclient/node';

import { log, assert, isValidExecutable, fileExists } from './util';
// import { RunnableCodeLensProvider } from "./run";
import { PersistentState } from './persistent_state';
import { Config } from './config';
// import { fetchRelease, download } from './net';
// import { getPathForExecutable, isOdinInstalled } from './toolchain';
import { Ctx } from './ctx';
// import { runDebugTest, runTest } from './commands';
// import { watchOlsConfigFile } from './watch';

const onDidChange: vscode.EventEmitter<void> = new vscode.EventEmitter<void>();

let ctx: Ctx;


class DLSLanguageClient extends LanguageClient {
    importPaths: string[];

    fillInitializeParams(params: InitializeParams) {
        // fix https://github.com/johnsoncodehk/volar/issues/1959

        params.initializationOptions = {
            importPaths: this.importPaths
        }
    }
}

export async function activate(context: vscode.ExtensionContext) {

    const config = new Config(context);
    const state = new PersistentState(context.globalState);

    log.setEnabled(true);

    const serverPath = await bootstrap(config, state).catch(err => {
        let message = "bootstrap error. ";

        if (err.code === "EBUSY" || err.code === "ETXTBSY" || err.code === "EPERM") {
            message += "Other vscode windows might be using dls, ";
            message += "you should close them and reload this window to retry. ";
        }

        log.error("Bootstrap error", err);
        throw new Error(message);
    });


    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];

    if (workspaceFolder === undefined) {
        throw new Error("no folder is opened");
    }
 
    if (!serverPath) {
        vscode.window.showErrorMessage("Failed to find dls executable!");
        return;
    }


    var imports = get_imports(config);


    log.info("imports: ", imports);

    let serverOptions: ServerOptions = {
        command: serverPath,
        args: [
        ],
        options: {
            cwd: path.dirname(serverPath),
        },
    };

    let clientOptions: LanguageClientOptions = {
        documentSelector: [{ scheme: 'file', language: 'd' }],
        outputChannel: vscode.window.createOutputChannel("D Language Server")
    };

    var client = new DLSLanguageClient(
        'dls',
        'D Language Server Client',
        serverOptions,
        clientOptions
    );
    client.importPaths = imports;

    ctx = await Ctx.create(config, client, context, serverPath, workspaceFolder.uri.fsPath);

    vscode.commands.registerCommand("dls.start", () => {
        client.start();
    });

    vscode.commands.registerCommand("dls.stop", async () => {
        await client.stop();
    });

    vscode.commands.registerCommand("dls.restart", async () => {
        await client.stop();
        client.start();
    });

    vscode.workspace.onDidChangeConfiguration(event => {
        let affected = event.affectsConfiguration("dls.server.imports");
        if (affected) {
            var newImports = get_imports(config);
            client.sendRequest("dls/imports", newImports).then(data => console.log(data));
        }
    });

    client.start();
}

function get_imports(config: Config): string[]
{
    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
    var imports = [];
    config.imports.forEach(function (value) {

        if (fileExists(value))
        {
            log.info("path:",value,"exists");
            imports.push(value);
        }
        else
        {
            var p = vscode.Uri.joinPath(workspaceFolder.uri, value).fsPath;
            if (fileExists(p))
            {
                log.info("combined path:",value,"exists");
                imports.push(p);
            }
        }
    });
    return imports;
}

async function bootstrap(config: Config, state: PersistentState): Promise<string> {
    await fs.mkdir(config.globalStorageUri.fsPath, { recursive: true });

    const path = await bootstrapServer(config, state);

    return path;
}

async function bootstrapServer(config: Config, state: PersistentState): Promise<string> {
    const path = await getServer(config, state);
    if (!path) {
        throw new Error(
            "dls is not available. " +
            "Please, ensure it is installed."
        );
    }

    log.info("Using dls at", path);

    return path;
}


async function getServer(config: Config, state: PersistentState): Promise<string | undefined> {
    return config.serverPath;
}


export function deactivate(): Thenable<void> {
    return ctx!.client.stop();
}
