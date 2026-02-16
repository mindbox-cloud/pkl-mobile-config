# Mobile Config Generator (Pkl)

JSON config generator for Mobile SDK using the [Pkl](https://pkl-lang.org/) language.

## Project Structure

```
templates/                                — type definitions and defaults
  ConfigTemplate.pkl                      — full config with all sections and defaults
  SettingsTemplate.pkl                    — Settings, Operations, TTL, SlidingExpiration, etc.
  InAppsTemplate.pkl                      — InApp, targeting nodes, form variants
  MonitoringTemplate.pkl                  — Monitoring logs
  ABTestsTemplate.pkl                     — A/B tests

configs/                                  — concrete configurations (working files)
  Config.pkl                              — main config (monitoring + settings + inapps)
  InApps.pkl                              — in-app message data for Config.pkl
  Settings.pkl                            — settings with all operations
  SettingWithoutSetCartOperation.pkl       — settings without setCart
  SettingsWithoutOperations.pkl           — settings without operations
  ABTest.pkl                              — A/B tests
configs/stubs/                              — test stubs (62 files)
  Config/                                   — full config error stubs
    _ConfigBase.pkl                         — base config for all Config stubs
  Settings/                                 — settings error stubs
    _SettingsBase.pkl                       — base for standard settings stubs
    _SettingsInAppBase.pkl                  — base for InApp settings stubs
    OperationsErrors/                       — operations field errors
    TtlErrors/                              — TTL field errors
    SlidingExpirationsError/                — sliding expiration errors
    InappError/                             — inapp settings errors
  Monitoring/                               — monitoring log errors
  ABTests/                                  — A/B test errors
```

## Commands

**Build main config as JSON:**
```bash
pkl eval configs/Config.pkl -f json
```

**Output to file:**
```bash
pkl eval configs/Config.pkl -f json -o output/config.json
```

**Build a specific settings variant:**
```bash
pkl eval configs/Settings.pkl -f json
pkl eval configs/SettingsWithoutOperations.pkl -f json
pkl eval configs/SettingWithoutSetCartOperation.pkl -f json
```

**Output as YAML (or other format):**
```bash
pkl eval configs/Config.pkl -f yaml
pkl eval configs/Config.pkl -f plist
```

## Creating New Configs

### New full config (amends ConfigTemplate)

Create a file in `configs/` that amends the config template. Only override what differs from defaults:

```pkl
amends "../templates/ConfigTemplate.pkl"

// settings, abtests — taken from defaults (all fields included automatically)
// abtests defaults to null

monitoring {
  logs {
    new {
      requestId = "your-uuid"
      deviceUUID = "device-uuid"
      from = "2024-01-01T00:00:00"
      to = "2024-01-02T00:00:00"
    }
  }
}

// Override settings only if needed:
settings {
  operations {
    setCart = null  // disable setCart
  }
}
```

Default config output includes all sections: `monitoring`, `settings` (with `operations`, `ttl`, `slidingExpiration`, `inapp`, `featureToggles`), `inapps`, `abtests`.

### New settings variant

Create a file in `configs/` that amends the template:
```pkl
amends "../templates/SettingsTemplate.pkl"

settings {
  operations {
    viewProduct {
      systemName = "myCustomProduct"
    }
    viewCategory = null   // disable operation
    setCart = null
  }
  // ttl, slidingExpiration, inapp, featureToggles — taken from defaults
}
```

### New set of in-app messages

Create a file in `configs/` that amends the InApps template:
```pkl
amends "../templates/InAppsTemplate.pkl"

import "../templates/InAppsTemplate.pkl"

inapps {
  new {
    id = "your-uuid-here"
    sdkVersion {
      min = 9
      max = null
    }
    frequency {
      kind = "lifetime"
      $type = "once"
    }
    targeting {
      nodes {
        new InAppsTemplate.TrueNode {}
      }
      $type = "and"
    }
    form {
      variants {
        new InAppsTemplate.SimpleImageVariant {
          imageUrl = "https://example.com/image.jpg"
          redirectUrl = "https://example.com"
          intentPayload = ""
        }
      }
    }
  }
}
```

## Targeting Nodes

Each node is a logical function that returns `true` / `false` / `undefined`.
Nodes are combined via `and` / `or` (nesting is supported).

| Node | Purpose | Fields |
|---|---|---|
| `TrueNode` | Always true | — |
| `ApiMethodCallNode` | API method call | `systemName`, `internalId?` |
| `VisitNode` | Visit count | `kind`, `value` |
| `ViewProductIdNode` | Product ID match | `kind` (substring/notSubstring/startsWith/endsWith), `value` |
| `ViewProductCategoryIdNode` | Product category ID match | `kind` (substring/notSubstring/startsWith/endsWith), `value` |
| `ViewProductCategoryIdInNode` | Product category ID in set | `kind` (any/none), `valuee` (string list) |
| `SegmentNode` | Customer segment | `kind` (positive/negative), `segmentationInternalId`, `segmentationExternalId`, `segmentExternalId` |
| `ViewProductSegmentNode` | Product segment | same as SegmentNode |
| `CountryNode` | Country by geo IDs | `kind` (positive/negative), `ids` |
| `RegionNode` | Region by geo IDs | `kind` (positive/negative), `ids` |
| `CityNode` | City by geo IDs | `kind` (positive/negative), `ids` |

Evaluation logic (1=true, 0=false, ?=undefined):

| A | B | AND | OR |
|---|---|-----|-----|
| 0 | 0 | 0 | 0 |
| 0 | ? | 0 | ? |
| 0 | 1 | 0 | 1 |
| 1 | 0 | 0 | 1 |
| 1 | ? | ? | 1 |
| 1 | 1 | 1 | 1 |

### Nested targeting example

```pkl
targeting {
  nodes {
    new InAppsTemplate.Targeting {
      nodes {
        new InAppsTemplate.CountryNode {
          kind = "positive"
          ids { 2017370 }
        }
        new InAppsTemplate.RegionNode {
          kind = "positive"
          ids { 123 }
        }
      }
      $type = "or"
    }
    new InAppsTemplate.SegmentNode {
      kind = "positive"
      segmentationInternalId = "..."
      segmentationExternalId = "..."
      segmentExternalId = "..."
    }
  }
  $type = "and"
}
```

Result: `(country OR region) AND segment`.

## Form Variants

| Variant | Purpose | Key fields |
|---|---|---|
| `ModalVariant` | Modal window | `content` (background + elements), `imageUrl`, `redirectUrl`, `intentPayload` |
| `SnackbarVariant` | Snackbar | `content` (background + position + elements), `imageUrl`, `redirectUrl`, `intentPayload` |
| `SimpleImageVariant` | Simple image | `imageUrl`, `redirectUrl`, `intentPayload` |

## Settings

Default values (defined in `templates/SettingsTemplate.pkl`):

| Parameter | Default |
|---|---|
| `ttl.inapps` | `"1.00:00:00"` |
| `slidingExpiration.config` | `"00:30:00"` |
| `slidingExpiration.pushTokenKeepalive` | `"14.00:00:00"` |
| `inapp.maxInappsPerSession` | `3` |
| `inapp.maxInappsPerDay` | `50` |
| `inapp.minIntervalBetweenShows` | `"00:00:10"` |
| `featureToggles.MobileSdkShouldSendInAppShowError` | `false` |

TimeSpan format: `[-][d.]hh:mm:ss[.fffffff]` (C# TimeSpan).

## Test Stubs

62 Pkl stubs generate JSON for SDK parsing tests. All stubs inherit defaults from templates, so adding a new section (e.g. `featureToggles`) automatically appears in all generated JSON.

**Generate all stubs:**
```bash
bash generate.sh
```

### Stub Architecture

Stubs inherit from base configs via `amends` or `import`:
- **Valid stubs** — `amends "_ConfigBase.pkl"` (inherit everything)
- **Error stubs** — `import "_ConfigBase.pkl" as base` + programmatic transforms

### Error Generation Patterns

All patterns use `toMap()` to convert typed objects, transform them, then `toDynamic()` for JSON output.

**Rename a key:**
```pkl
import "_ConfigBase.pkl" as base

output {
  renderer = new JsonRenderer { omitNullProperties = false }
  value = base.configMap.toMap()
    .mapKeys((key, _) -> if (key == "abtests") "abtestsTest" else key)
    .toDynamic()
}
```

**Replace a value with wrong type:**
```pkl
import "../_SettingsInAppBase.pkl" as base

output {
  renderer = new JsonRenderer {}
  value = base.settings.toMap()
    .mapValues((key, value) -> if (key == "inapp") 123 else value)
    .toDynamic()
}
```

**Remove a key (missing field):**
```pkl
import "../_SettingsInAppBase.pkl" as base

output {
  renderer = new JsonRenderer {}
  value = base.settings.toMap()
    .mapValues((key, value) ->
      if (key == "inapp") value.toMap().filter((k, _) -> k != "maxInappsPerDay").toDynamic()
      else value
    )
    .toDynamic()
}
```

**Transform a specific element in a Listing:**
```pkl
import "../../../templates/MonitoringTemplate.pkl"

logs = new Listing {
  MonitoringTemplate.logs[0].toMap()
    .mapKeys((key, _) -> if (key == "requestId") "request" else key)
    .toDynamic()
  MonitoringTemplate.logs[1]
}
```

### Adding New Sections

When you add a new section to a template (e.g. a new field in `SettingsTemplate.Settings`):
1. All valid stubs automatically include the new section in JSON output
2. Error stubs that use `toMap()` transforms also include it automatically
3. No manual updates to individual stubs needed
