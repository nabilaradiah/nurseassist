# 4. ML model

## What ships in the app

| | |
|---|---|
| File | `assets/models/wound_classifier.tflite` |
| Architecture | EfficientNetB0 (ImageNet weights), fine-tuned, with a small classification head |
| Input | `float32 [1, 224, 224, 3]`, RGB, **pixel values 0–255** (the model normalises internally, so don't divide by 255) |
| Output | `float32 [1, 8]` softmax. Index 0 = Type 1 … index 7 = Type 8 |
| Runs | On the phone with `tflite_flutter`, 2 threads. No network |
| Settings | `lib/services/ai_config.dart` |

## How the app uses it (`WoundAnalysisService.analyzeWound`)

1. **Skin gate.** ML Kit selfie segmentation (`SkinDetectionService`) counts pixels it thinks are a person. Under **4 %** (`skinDetectionMinRatio`) → "No skin detected", retake. If ML Kit itself fails, the photo is let through rather than blocked.
2. **Preprocess.** Decode the image and resize it to 224 × 224 (`package:image` `copyResize`).
3. **Inference** → 8 probabilities → the highest is the AI's type.
4. **No-wound guard.** Top probability under **0.35** (`noWoundConfidenceThreshold`) → "No wound detected", retake.
5. Build the result: the type, confidence, all 8 probabilities, and the management plan from `WoundTypesDatabase`.

If the model fails to load or run, `AiUnavailableException` is thrown and the nurse carries on with the TIME(S) assessment alone. There is deliberately **no fallback guess**.

Both gates can be switched off in `ai_config.dart` for testing (`skinDetectionEnabled`, `noWoundDetectionEnabled`). Switch them back on before any real use.

The AI's probabilities are also turned into per-factor probabilities (`TimProbabilities`): how likely it is over 25 % necrotic, infected, or wet. That lets the results screen say which TIME factor the AI is unsure about.

## Training

The notebook is [`ml/wound_efficientnetb0_training.ipynb`](../ml/wound_efficientnetb0_training.ipynb). It runs on **Google Colab with a T4 GPU**. Its title cell still says "EfficientNetV2-S" from an earlier version. The model it actually builds (cell 14) is EfficientNetB0.

What it does:
1. Unzips the dataset from Google Drive. It expects folders `TYPE 1` … `TYPE 8`.
2. Splits 80 / 10 / 10, stratified by class, seed 42.
3. Oversamples the small classes (Type 3 and Type 4 are boosted the most) and applies heavy augmentation: flips, 90° rotations, crops, colour jitter.
4. Trains in two phases with **focal loss** (γ = 2, label smoothing 0.1) plus class weights:
   * Phase 1: backbone frozen, 25 epochs, lr 1e-3.
   * Phase 2: top 20 backbone layers unfrozen, 25 epochs, lr 5e-6.
5. Evaluates on the test split with **test-time augmentation** (5 passes), then prints a confusion matrix and per-class confidence.
6. Converts to TFLite (default optimisation) and downloads `wound_classifier.tflite` and `wound_labels.txt`.

`wound_labels.txt` isn't used by the app. The label order is fixed in code (Type_1 … Type_8).

### Replacing the model

1. Run the notebook and download `wound_classifier.tflite`.
2. Replace `assets/models/wound_classifier.tflite`. Keep the same input/output shape and class order, or update `ai_config.dart` and `WoundAnalysisService` to match.
3. Re-check `noWoundConfidenceThreshold` against the notebook's per-class confidence analysis (cell 21). A new model can be more or less confident overall.
4. Test on a real phone with real wound photos (from the dataset, not patients) and with non-wound photos. Confirm the gates still behave.
5. Record the new model's test results and the date in this file.

## Dataset

* **8 folders, `TYPE 1` … `TYPE 8`, 721 images at handover**: 108 / 152 / 35 / 41 / 102 / 65 / 84 / 134. Types 3 and 4 are the smallest, and they are also the ones the model confuses most.
* Labels follow the Wound Care Quick Reference typing (see [Clinical content](05-clinical-content.md)).
* The images are **not in this repository** and must never be committed. They are handed over separately, as a zip, with the documents.
* Before using or extending the dataset, confirm with your supervisor where each image came from and that its use is covered by consent and ethics approval. Keep a record of that with the dataset.

### Growing the dataset from the app

The lecturer approval queue is the retraining loop. Each approved assessment's photo is copied to Storage at `training-data/approved/type_N/`, using the final, lecturer-checked type. To retrain:

1. Download `training-data/approved/` (Firebase console, or `gcloud storage cp -r gs://<bucket>/training-data/approved ./approved`).
2. Merge each `type_N` folder into the dataset's `TYPE N` folder. Watch for duplicates.
3. Re-zip and run the notebook.

## Known weaknesses

These are all also listed in [Known issues](07-known-issues.md).

* **Preprocessing doesn't match training.** The app resizes with nearest-neighbour. Training uses bilinear resizing (`tf.image.resize`). Use `img.copyResize(..., interpolation: img.Interpolation.linear)` to match.
* **No EXIF orientation fix.** Phone photos can reach the model rotated. Call `img.bakeOrientation(decoded)` after decoding. Training's random rotations soften this but don't remove it.
* **The skin check runs twice per photo**, once in `analyzeWound` and again in `_analyzeWithTFLite`. Remove one.
* **Decode and inference run on the UI thread**, so the app can stutter while analysing. Move them to an isolate (`compute` / `Isolate.run`, or `IsolateInterpreter` from `tflite_flutter`).
* **The reported accuracy is optimistic.**
  * The split is per image, not per patient. Photos of the same wound can land in both train and test.
  * The test score uses test-time augmentation, which the app doesn't do.

  For an honest number, split by patient and evaluate without TTA.
* **The dataset is small** (721 images, 35–41 for Types 3–4). Treat the AI as a suggestion. That's why the nurse's TIME(S) assessment, not the AI, sets the recorded type.

## Experiments that didn't ship

The `NurseAssist_documents/ml` folder also has a ViT (vision transformer) training notebook and a MedSAM3 segmentation-and-crop preprocessing notebook, along with the generator scripts (`gen_notebook.py`, `gen_preprocess_notebook.py`) that wrote all the notebooks. They were tried and not adopted. (The training notebook notes that a larger CNN, EfficientNetV2-S, reached only about 40 % on this small dataset, which is why the smaller B0 was chosen.) They're a starting point if you want to try wound segmentation or measurement.
