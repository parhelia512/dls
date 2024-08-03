# dls is a LSP for D (WIP)


- Supports templates (with my fork of DCD)
- Fast to compile
- Lower memory footprint
- Faster due to using DCD as a library directly



# Build

Linux only for now, once ready, i'll setup CI/CD for Linux/macOS/Windows


```
make build-dcd
make build-dls
```

# Editors

- VSCode:

```
make build-vscode
```

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
