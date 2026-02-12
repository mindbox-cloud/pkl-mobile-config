# Mobile Config Generator (Pkl)

JSON config generator for Mobile SDK using the [Pkl](https://pkl-lang.org/) language.

## Project Structure

```
templates/                                — type definitions and defaults
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

### New full config (monitoring + settings + inapps)

Copy `configs/Config.pkl` and modify the data:
```bash
cp configs/Config.pkl configs/MyConfig.pkl
```

Then edit `configs/MyConfig.pkl` — change settings, point to a different InApps file, etc.

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
