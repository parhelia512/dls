# dls is a LSP for D (WIP)


- Supports templates (with my fork of DCD)
- Fast to compile
- Lower memory footprint
- Faster due to using DCD as a library directly

![image](https://github.com/user-attachments/assets/7e58302c-3585-4d27-9b05-b301e1887d73)


# Build

Linux and Windows only for now, once ready, i'll setup CI/CD for macOS/FreeBSD asap


```
make build-dcd-release
make build-dls-release
```

# Editors

- VSCode:

    - `make build-vscode`

```json5
    "dls.server.path":  "/home/ryuukk/dev/dls/bin/dls",
    "dls.server.imports": [
      "/home/you/project_b/",
      "projects_a/", // relative to root folder
    ],
```

- Sublime Text:
    - install sublime's LSP extension
```json5
    "dls": {
        "enabled": true,
        "command": ["/home/ryuukk/dev/dls/bin/dls"],
        "selector": "source.d",
        "initializationOptions": {
            "importPaths": [
              "/home/you/project_b/",
              "projects_a/", // relative to root folder
            ],
        },
    },
```

- Zed:
    - Extensions -> Install Dev Extension
    - point to `editors/zed/`
```json5
    "lsp": {
        "dls":{
          "initialization_options": {
            "importPaths": [
              "/home/you/project_b/",
              "projects_a/", // relative to root folder
            ]
          }
        },
    }
```
