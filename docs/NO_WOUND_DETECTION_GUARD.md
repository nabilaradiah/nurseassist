# No-Wound Detection Guard

## What it does

The ML model (TFLite EfficientNetB0) always outputs one of 8 wound types — even if the photo is of a hand, a wall, or anything that isn't a wound. The guard prevents those bad images from ever reaching the Analysis Results screen by checking the model's confidence against a minimum threshold. If the top class confidence is too low, the image is rejected and the user is prompted to retake the photo.

---

## Files changed

| File | What was added |
|------|---------------|
| `lib/services/ai_config.dart` | `noWoundDetectionEnabled` toggle + `noWoundConfidenceThreshold` value |
| `lib/services/wound_analysis_service.dart` | `NoWoundDetectedException` class + threshold check inside `_analyzeWithTFLite()` + rethrow in the fallback catch |
| `lib/screens/capture_wound_screen.dart` | `on NoWoundDetectedException` catch block that resets the camera and shows a retake dialog |

---

## How to toggle the guard

Open `lib/services/ai_config.dart` and change this one line:

```dart
// ON  — guard is active (normal use)
static const bool noWoundDetectionEnabled = true;

// OFF — guard is bypassed (use this when testing non-wound images)
static const bool noWoundDetectionEnabled = false;
```

Rebuild the app after changing it (`flutter run`). No other files need to be touched.

---

## How to tune the threshold

Also in `lib/services/ai_config.dart`:

```dart
static const double noWoundConfidenceThreshold = 0.35;
```

| Threshold | Behaviour |
|-----------|-----------|
| `0.50` | Stricter — rejects anything the model isn't at least 50% sure about |
| `0.35` | Default starting point — rejects clearly non-wound images |
| `0.25` | More lenient — only rejects images the model is very unsure about |

**How to find the right value for your model:**
1. Set `noWoundDetectionEnabled = false` so everything passes through.
2. Take test photos: a real wound, a plain hand, a wall, a shoe, etc.
3. Check the debug console — it prints the full softmax probabilities for every TFLite run, e.g.:
   ```
   🎯 TFLite → Type_3  confidence: 28.4%
      Full probabilities: Type_1: 5.2%, Type_2: 11.0%, Type_3: 28.4%, ...
   ```
4. Note the confidence values for non-wound images. Set the threshold just above the highest non-wound confidence you observe.
5. Re-enable the guard (`noWoundDetectionEnabled = true`) and test again.

---

## Runtime flow

```
User presses "Confirm & Analyze"
        │
        ▼
Privacy confirmation dialog
        │
        ▼
Progress dialog shown ("Uploading…", "Analyzing…")
        │
        ▼
TFLite runs → gets 8 softmax probabilities
        │
        ├─ top confidence >= threshold  ──→  normal analysis result → AnalysisResultsScreen
        │
        └─ top confidence < threshold (and guard is ON)
                │
                ▼
        NoWoundDetectedException thrown
                │
                ▼
        Progress dialog closes
        Camera resets to capture mode
        Orange "No Wound Detected" dialog shown
```

---

## The dialog shown to the user

When a non-wound image is detected, the user sees:

> **No Wound Detected**
>
> The image does not appear to contain a wound.
>
> Please retake the photo with the wound clearly in the centre of the frame.
>
> [ Retake Photo ]

The camera is automatically reset to capture mode when they dismiss the dialog.

---

## Important notes

- The guard **only applies to the `tflite` analysis path**. The `enhanced_mock` and `cloud` paths are not affected, so fallback testing still works normally.
- Turning the guard off (`noWoundDetectionEnabled = false`) does not remove any code — the threshold check is simply skipped.
- The `NoWoundDetectedException` is defined at the top of `wound_analysis_service.dart`. It is explicitly reThrown from the generic fallback catch so it is never silently swallowed into the enhanced-rules fallback.
- The threshold `0.35` is a starting point. Real calibration depends on your specific TFLite model's output distribution, so always tune it with real test photos before submitting.
