import json, os

cells = []

cells.append({
    "cell_type": "markdown", "metadata": {},
    "source": [
        "# NurseAssist - Wound Classification (EfficientNetV2-S CNN)\n",
        "\n",
        "**Model:** EfficientNetV2-S CNN, pretrained on ImageNet, native TF/Keras\n",
        "\n",
        "**v2 Improvements for Type 3 / Type 4 accuracy:**\n",
        "- Focal Loss (gamma=2.0) instead of plain cross-entropy -- focuses on hard/confused examples\n",
        "- Per-class oversample targets: Type_3 & Type_4 boosted to 80 samples (was 45)\n",
        "- Random 90-degree rotation added to augmentation pipeline\n",
        "- Stronger brightness/contrast/saturation ranges for minority classes\n",
        "- Per-class confidence analysis cell to set inference threshold\n",
        "\n",
        "**Steps before running:**\n",
        "1. Runtime > Change runtime type > T4 GPU\n",
        "2. Upload 'zip wound type.zip' to your Google Drive\n",
        "3. Update ZIP_PATH in Cell 4\n",
        "4. Run all cells top to bottom"
    ]
})

def c(src):
    return {"cell_type": "code", "execution_count": None, "metadata": {}, "outputs": [],
            "source": src}

# ── CELL 1 ──────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 1 - Install Dependencies\n"
    "!pip install -q scikit-learn matplotlib seaborn pillow imbalanced-learn\n"
    "print('Done')"
))

# ── CELL 2 ──────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 2 - Mount Google Drive\n"
    "from google.colab import drive\n"
    "drive.mount('/content/drive')"
))

# ── CELL 3 ──────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 3 - Imports\n"
    "import os, random, zipfile\n"
    "import numpy as np\n"
    "import tensorflow as tf\n"
    "import matplotlib.pyplot as plt\n"
    "import seaborn as sns\n"
    "from PIL import Image\n"
    "from collections import defaultdict\n"
    "from sklearn.model_selection import train_test_split\n"
    "from sklearn.metrics import classification_report, confusion_matrix\n"
    "from sklearn.utils import resample\n"
    "from sklearn.utils.class_weight import compute_class_weight\n"
    "import warnings\n"
    "warnings.filterwarnings('ignore')\n"
    "SEED = 42\n"
    "random.seed(SEED); np.random.seed(SEED); tf.random.set_seed(SEED)\n"
    "print(f'TensorFlow {tf.__version__}')\n"
    "gpu = tf.test.gpu_device_name()\n"
    "print(f'GPU: {gpu if gpu else \"NONE - go to Runtime > Change runtime type > T4 GPU\"}')"
))

# ── CELL 4 ──────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 4 - Configuration    UPDATE ZIP_PATH BEFORE RUNNING\n"
    "# ── Dataset source ────────────────────────────────────────────────────\n"
    "# Set USE_PREPROCESSED = True after running wound_medsam3_preprocess.ipynb\n"
    "USE_PREPROCESSED   = False\n"
    "\n"
    "# If USE_PREPROCESSED = False  (original zip)\n"
    "ZIP_PATH           = '/content/drive/MyDrive/zip wound type.zip'      # <- CHANGE THIS\n"
    "\n"
    "# If USE_PREPROCESSED = True   (MedSAM3 wound-cropped + copy-paste aug)\n"
    "PROCESSED_ZIP_PATH = '/content/drive/MyDrive/wound_processed.zip'     # <- output from preprocess nb\n"
    "\n"
    "DATASET_PATH = '/content/wound_preprocessed' if USE_PREPROCESSED else '/content/wound_dataset'\n"
    "OUTPUT_DIR   = '/content/wound_output'\n"
    "os.makedirs(OUTPUT_DIR, exist_ok=True)\n"
    "\n"
    "IMG_SIZE  = 224\n"
    "BATCH_SIZE = 16    # reduce to 8 if out-of-memory\n"
    "EPOCHS_P1 = 25    # Phase 1: frozen backbone\n"
    "EPOCHS_P2 = 25    # Phase 2: fine-tune top layers\n"
    "LR_P1     = 1e-3\n"
    "LR_P2     = 5e-6   # reduced from 1e-5: Phase 2 was degrading accuracy (overfitting)\n"
    "VAL_RATIO  = 0.10\n"
    "TEST_RATIO = 0.10\n"
    "\n"
    "# Default minimum training samples for all classes\n"
    "MIN_TRAIN_SAMPLES = 45\n"
    "\n"
    "# !! KEY FIX: Per-class oversample targets.\n"
    "# Per-class oversample targets.\n"
    "# Types 3/4/5 had critically few real images; 6/7 also underrepresented.\n"
    "# Type_5 was at 0% F1 in first run - added here as an urgent fix.\n"
    "CLASS_OVERSAMPLE_TARGETS = {\n"
    "    2: 80,   # Type_3 - ~9 real images\n"
    "    3: 80,   # Type_4 - ~13 real images\n"
    "    4: 80,   # Type_5 - ~20 real images (was 0% F1, urgent fix)\n"
    "    5: 60,   # Type_6 - ~40 real images\n"
    "    6: 60,   # Type_7 - ~40 real images\n"
    "}\n"
    "\n"
    "# Focal Loss gamma.  2.0 is the standard value.\n"
    "# Higher gamma = more focus on hard/confused samples.\n"
    "FOCAL_LOSS_GAMMA = 2.0\n"
    "\n"
    "# Confidence threshold for inference.\n"
    "# Predictions below this suggest manual specialist review.\n"
    "CONFIDENCE_THRESHOLD = 0.60\n"
    "\n"
    "print(f'USE_PREPROCESSED : {USE_PREPROCESSED}')\n"
    "print(f'Dataset zip      : {PROCESSED_ZIP_PATH if USE_PREPROCESSED else ZIP_PATH}')\n"
    "print(f'Output dir       : {OUTPUT_DIR}')\n"
    "print(f'Focal Loss gamma : {FOCAL_LOSS_GAMMA}')\n"
    "print(f'Oversample targets: {CLASS_OVERSAMPLE_TARGETS}')"
))

# ── CELL 5 ──────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 5 - Wound Type Definitions\n"
    "FOLDER_NAMES = ['TYPE 1','TYPE 2','TYPE 3','TYPE 4','TYPE 5','TYPE 6','TYPE 7','TYPE 8']\n"
    "WOUND_LABELS = ['Type_1','Type_2','Type_3','Type_4','Type_5','Type_6','Type_7','Type_8']\n"
    "SPECIALIST_CONFIRM = ['Type_3', 'Type_4', 'Type_6']  # specialist review before debridement\n"
    "NUM_CLASSES = len(WOUND_LABELS)\n"
    "id2label  = {i: l for i, l in enumerate(WOUND_LABELS)}\n"
    "folder2id = {f: i for i, f in enumerate(FOLDER_NAMES)}\n"
    "for i, (f, l) in enumerate(zip(FOLDER_NAMES, WOUND_LABELS)):\n"
    "    star = '  ** MINORITY **' if i in CLASS_OVERSAMPLE_TARGETS else ''\n"
    "    print(f'  [{i}] {f}  ->  {l}{star}')"
))

# ── CELL 6 ──────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 6 - Extract Zip\n"
    "VALID_EXTS = ('.jpg', '.jpeg', '.png', '.bmp', '.tif', '.tiff')\n"
    "_zip_to_use = PROCESSED_ZIP_PATH if USE_PREPROCESSED else ZIP_PATH\n"
    "if not os.path.exists(DATASET_PATH) or not os.listdir(DATASET_PATH):\n"
    "    src_label = 'preprocessed (MedSAM3)' if USE_PREPROCESSED else 'original'\n"
    "    print(f'Extracting {src_label} dataset from {_zip_to_use} ...')\n"
    "    with zipfile.ZipFile(_zip_to_use, 'r') as z:\n"
    "        z.extractall(DATASET_PATH)\n"
    "    print('Done')\n"
    "else:\n"
    "    print(f'Already extracted  (USE_PREPROCESSED={USE_PREPROCESSED})')\n"
    "total = 0\n"
    "for folder in sorted(os.listdir(DATASET_PATH)):\n"
    "    fp = os.path.join(DATASET_PATH, folder)\n"
    "    if not os.path.isdir(fp): continue\n"
    "    n = len([f for f in os.listdir(fp) if f.lower().endswith(VALID_EXTS)])\n"
    "    total += n\n"
    "    flag = '  <- VERY FEW' if n < 20 else ('  <- LOW' if n < 35 else '')\n"
    "    print(f'{folder:<10} {n:>6}{flag}')\n"
    "print(f'TOTAL      {total:>6}')"
))

# ── CELL 7 ──────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 7 - Load and Validate Images\n"
    "def load_dataset(path):\n"
    "    paths, labels, bad = [], [], []\n"
    "    for folder in FOLDER_NAMES:\n"
    "        fp = os.path.join(path, folder)\n"
    "        if not os.path.exists(fp):\n"
    "            print(f'  WARNING: missing folder {fp}')\n"
    "            continue\n"
    "        lid = folder2id[folder]\n"
    "        for fname in os.listdir(fp):\n"
    "            if not fname.lower().endswith(VALID_EXTS): continue\n"
    "            full = os.path.join(fp, fname)\n"
    "            try:\n"
    "                img = Image.open(full)\n"
    "                img.verify()\n"
    "                paths.append(full)\n"
    "                labels.append(lid)\n"
    "            except Exception:\n"
    "                bad.append(full)\n"
    "    if bad: print(f'Skipped {len(bad)} corrupt files')\n"
    "    return paths, labels\n"
    "print('Loading images...')\n"
    "image_paths, labels = load_dataset(DATASET_PATH)\n"
    "labels_array = np.array(labels)\n"
    "print(f'{len(image_paths)} valid images loaded')"
))

# ── CELL 8 ──────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 8 - Class Distribution Chart\n"
    "counts = [int(np.sum(labels_array == i)) for i in range(NUM_CLASSES)]\n"
    "colors = ['#e74c3c' if c < 20 else '#f39c12' if c < 35 else '#2ecc71' for c in counts]\n"
    "plt.figure(figsize=(11, 4))\n"
    "bars = plt.bar(WOUND_LABELS, counts, color=colors, edgecolor='white')\n"
    "plt.title('Dataset Class Distribution (Red<20  Orange<35  Green=OK)', fontweight='bold')\n"
    "plt.xlabel('Wound Type'); plt.ylabel('Images'); plt.xticks(rotation=30)\n"
    "for bar, cc in zip(bars, counts):\n"
    "    plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.3,\n"
    "             str(cc), ha='center', fontweight='bold')\n"
    "plt.tight_layout()\n"
    "plt.savefig(f'{OUTPUT_DIR}/class_distribution.png', dpi=150)\n"
    "plt.show()\n"
    "print(f'Imbalance ratio: {max(counts)/max(min(counts),1):.1f}x')"
))

# ── CELL 9 ──────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 9 - Train/Val/Test Split (stratified)\n"
    "def safe_split(paths, lbls, test_size, seed):\n"
    "    try:\n"
    "        return train_test_split(paths, lbls, test_size=test_size, stratify=lbls, random_state=seed)\n"
    "    except ValueError:\n"
    "        print('  Stratified split failed, using random split')\n"
    "        return train_test_split(paths, lbls, test_size=test_size, random_state=seed)\n"
    "temp = VAL_RATIO + TEST_RATIO\n"
    "train_p, temp_p, train_l, temp_l = safe_split(image_paths, labels, temp, SEED)\n"
    "val_p, test_p, val_l, test_l     = safe_split(temp_p, temp_l, TEST_RATIO / temp, SEED)\n"
    "print(f'Train: {len(train_p)} | Val: {len(val_p)} | Test: {len(test_p)}')\n"
    "# Show per-class test counts so we know which classes appear in test evaluation\n"
    "test_arr = np.array(test_l)\n"
    "for i, lbl in enumerate(WOUND_LABELS):\n"
    "    n = int(np.sum(test_arr == i))\n"
    "    print(f'  {lbl}: {n} test samples{\" <- may not appear in test set\" if n == 0 else \"\"}')"
))

# ── CELL 10 ─────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 10 - Oversample Minority Classes with Per-Class Targets\n"
    "# Type_3 and Type_4 get boosted to 80 samples (vs 45 for others).\n"
    "# Combined with aggressive augmentation, each 'copy' looks different.\n"
    "def oversample_perclass(paths, lbls, default_min, targets_dict, seed):\n"
    "    buckets = defaultdict(list)\n"
    "    for p, l in zip(paths, lbls): buckets[l].append(p)\n"
    "    out_p, out_l = [], []\n"
    "    for lid, ps in sorted(buckets.items()):\n"
    "        orig = len(ps)\n"
    "        target = targets_dict.get(lid, default_min)\n"
    "        if len(ps) < target:\n"
    "            ps = resample(ps, n_samples=target, replace=True, random_state=seed)\n"
    "            print(f'  {WOUND_LABELS[lid]}: {orig} -> {target} (oversampled)')\n"
    "        else:\n"
    "            print(f'  {WOUND_LABELS[lid]}: {len(ps)} (unchanged)')\n"
    "        out_p.extend(ps)\n"
    "        out_l.extend([lid] * len(ps))\n"
    "    combined = list(zip(out_p, out_l))\n"
    "    random.seed(seed); random.shuffle(combined)\n"
    "    return [x[0] for x in combined], [x[1] for x in combined]\n"
    "\n"
    "print('Oversampling training set...')\n"
    "train_p_bal, train_l_bal = oversample_perclass(\n"
    "    train_p, train_l, MIN_TRAIN_SAMPLES, CLASS_OVERSAMPLE_TARGETS, SEED\n"
    ")\n"
    "print(f'Training: {len(train_p)} -> {len(train_p_bal)} samples after oversampling')"
))

# ── CELL 11 ─────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 11 - Focal Loss + Class Weights\n"
    "#\n"
    "# WHY FOCAL LOSS instead of plain cross-entropy?\n"
    "# With plain cross-entropy the model can get high overall accuracy by\n"
    "# being good at well-represented classes and ignoring rare ones.\n"
    "# Focal loss down-weights 'easy' correct predictions and forces the\n"
    "# model to pay attention to the hard/confused examples (Type_3/4).\n"
    "#\n"
    "# Formula:  FL = -(1-p_t)^gamma * log(p_t)\n"
    "# When gamma=0  -> identical to cross-entropy\n"
    "# When gamma=2  -> well-classified samples (p_t~1) contribute ~4x less\n"
    "\n"
    "def focal_loss(gamma=2.0, label_smoothing=0.1):\n"
    "    \"\"\"\n"
    "    Sparse-label focal loss with label smoothing.\n"
    "    label_smoothing=0.1: softens hard targets (1.0 -> 0.9, 0.0 -> 0.0111...)\n"
    "    This prevents the model from becoming overconfident on ambiguous wound types.\n"
    "    \"\"\"\n"
    "    def loss_fn(y_true, y_pred):\n"
    "        eps = tf.keras.backend.epsilon()\n"
    "        y_pred = tf.clip_by_value(y_pred, eps, 1.0 - eps)\n"
    "        y_true_int = tf.cast(tf.reshape(y_true, [-1]), tf.int32)\n"
    "        y_true_oh  = tf.one_hot(y_true_int, depth=NUM_CLASSES)\n"
    "        # Apply label smoothing: mix true labels with uniform distribution\n"
    "        y_smooth = y_true_oh * (1.0 - label_smoothing) + label_smoothing / NUM_CLASSES\n"
    "        p_t = tf.reduce_sum(y_smooth * y_pred, axis=-1)  # [batch]\n"
    "        focal_weight = tf.pow(1.0 - p_t, gamma)\n"
    "        ce   = -tf.reduce_sum(y_smooth * tf.math.log(y_pred), axis=-1)\n"
    "        return focal_weight * ce\n"
    "    loss_fn.__name__ = f'focal_loss_g{gamma}_ls{label_smoothing}'\n"
    "    return loss_fn\n"
    "\n"
    "# Compute class weights - still useful alongside focal loss\n"
    "# (class_weight is applied by model.fit per-sample BEFORE focal reweighting)\n"
    "classes = np.unique(train_l_bal)\n"
    "weights = compute_class_weight('balanced', classes=classes, y=train_l_bal)\n"
    "class_weight_dict = dict(zip(classes.tolist(), weights.tolist()))\n"
    "print(f'Focal Loss gamma = {FOCAL_LOSS_GAMMA}  (0=CrossEntropy, 2=Standard Focal)')\n"
    "print('Class weights (applied additionally by model.fit):')\n"
    "for cid, w in class_weight_dict.items():\n"
    "    print(f'  {WOUND_LABELS[cid]}: {w:.3f}')"
))

# ── CELL 12 ─────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 12 - tf.data Pipeline with Augmentation\n"
    "# EfficientNetV2 handles its own normalisation (include_preprocessing=True).\n"
    "# Pass raw pixels [0, 255] - do NOT divide by 255.\n"
    "#\n"
    "# v2 augmentation additions:\n"
    "#   - tf.image.rot90 with random k=0/1/2/3  (adds 4x rotational diversity)\n"
    "#   - Wider brightness/contrast/saturation ranges\n"
    "#   - Combined with oversampling, each repeated image looks visually unique\n"
    "\n"
    "def augment(img):\n"
    "    # Geometric\n"
    "    img = tf.image.random_flip_left_right(img)\n"
    "    img = tf.image.random_flip_up_down(img)\n"
    "    # Random 90-degree rotation (0 / 90 / 180 / 270)\n"
    "    k = tf.random.uniform([], minval=0, maxval=4, dtype=tf.int32)\n"
    "    img = tf.image.rot90(img, k)\n"
    "    # Random crop (simulate zoom-in up to ~12%)\n"
    "    padded = tf.image.resize_with_pad(img, IMG_SIZE + 28, IMG_SIZE + 28)\n"
    "    img    = tf.image.random_crop(padded, [IMG_SIZE, IMG_SIZE, 3])\n"
    "    # Colour jitter - wider ranges help minority classes\n"
    "    img = tf.image.random_brightness(img, max_delta=0.25)\n"
    "    img = tf.image.random_contrast(img, lower=0.75, upper=1.30)\n"
    "    img = tf.image.random_saturation(img, lower=0.70, upper=1.40)\n"
    "    img = tf.image.random_hue(img, max_delta=0.08)  # subtle - colour is clinically important\n"
    "    return tf.clip_by_value(img, 0.0, 255.0)\n"
    "\n"
    "def preprocess(path, label, training=False):\n"
    "    raw = tf.io.read_file(path)\n"
    "    img = tf.image.decode_image(raw, channels=3, expand_animations=False)\n"
    "    img = tf.cast(img, tf.float32)\n"
    "    img = tf.image.resize(img, [IMG_SIZE, IMG_SIZE])\n"
    "    if training: img = augment(img)\n"
    "    return img, label\n"
    "\n"
    "def make_ds(paths, lbls, training=False):\n"
    "    ds = tf.data.Dataset.from_tensor_slices((list(paths), list(lbls)))\n"
    "    if training: ds = ds.shuffle(len(paths), seed=SEED)\n"
    "    ds = ds.map(lambda p, l: preprocess(p, l, training), num_parallel_calls=tf.data.AUTOTUNE)\n"
    "    return ds.batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)\n"
    "\n"
    "train_ds = make_ds(train_p_bal, train_l_bal, training=True)\n"
    "val_ds   = make_ds(val_p, val_l)\n"
    "test_ds  = make_ds(test_p, test_l)\n"
    "print(f'Train: {len(train_ds)} | Val: {len(val_ds)} | Test: {len(test_ds)} batches')"
))

# ── CELL 13 ─────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 13 - Preview Augmented Samples\n"
    "batch_imgs, batch_lbls = next(iter(train_ds))\n"
    "n = min(12, len(batch_imgs))\n"
    "fig, axes = plt.subplots(2, 6, figsize=(18, 7))\n"
    "for i, ax in enumerate(axes.flatten()[:n]):\n"
    "    ax.imshow(np.clip(batch_imgs[i].numpy() / 255.0, 0, 1))\n"
    "    ax.set_title(id2label[int(batch_lbls[i].numpy())], fontsize=9)\n"
    "    ax.axis('off')\n"
    "plt.suptitle('Augmented training samples (rotation + colour jitter)', fontweight='bold')\n"
    "plt.tight_layout()\n"
    "plt.savefig(f'{OUTPUT_DIR}/augmented_samples.png', dpi=150)\n"
    "plt.show()"
))

# ── CELL 14 ─────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 14 - Build EfficientNetB0 Model\n"
    "# EfficientNetB0 (5.3M params) is chosen over EfficientNetV2-S (21.5M params)\n"
    "# because smaller datasets (~500 images) need smaller models to avoid overfitting.\n"
    "# EfficientNetV2-S was contributing to the 40.4% accuracy in the first run.\n"
    "inputs  = tf.keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3), name='input_image')\n"
    "backbone = tf.keras.applications.EfficientNetB0(\n"
    "    include_top=False,\n"
    "    weights='imagenet',\n"
    "    input_tensor=inputs,\n"
    "    include_preprocessing=True   # handles normalisation internally\n"
    ")\n"
    "backbone.trainable = False  # frozen for Phase 1\n"
    "x = backbone.output\n"
    "x = tf.keras.layers.GlobalAveragePooling2D()(x)\n"
    "x = tf.keras.layers.BatchNormalization()(x)\n"
    "x = tf.keras.layers.Dropout(0.4)(x)\n"
    "x = tf.keras.layers.Dense(128, activation='relu',\n"
    "                           kernel_regularizer=tf.keras.regularizers.l2(1e-4))(x)  # L2 reg prevents memorising training set\n"
    "x = tf.keras.layers.Dropout(0.3)(x)\n"
    "outputs = tf.keras.layers.Dense(NUM_CLASSES, activation='softmax', name='predictions')(x)\n"
    "model   = tf.keras.Model(inputs, outputs)\n"
    "total     = model.count_params()\n"
    "trainable = sum(tf.size(v).numpy() for v in model.trainable_variables)\n"
    "print(f'Total params   : {total:,}')\n"
    "print(f'Trainable (P1) : {trainable:,}  (head only, backbone frozen)')"
))

# ── CELL 15 ─────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 15 - Phase 1: Train Classification Head (Backbone Frozen)\n"
    "# Uses focal loss + class_weight together for maximum minority-class signal\n"
    "model.compile(\n"
    "    optimizer=tf.keras.optimizers.Adam(LR_P1),\n"
    "    loss=focal_loss(FOCAL_LOSS_GAMMA),\n"
    "    metrics=['accuracy']\n"
    ")\n"
    "cb1 = [\n"
    "    tf.keras.callbacks.EarlyStopping(monitor='val_accuracy', patience=8,\n"
    "                                     restore_best_weights=True, verbose=1),\n"
    "    tf.keras.callbacks.ReduceLROnPlateau(monitor='val_loss', factor=0.5,\n"
    "                                         patience=4, min_lr=1e-6, verbose=1),\n"
    "    tf.keras.callbacks.ModelCheckpoint(f'{OUTPUT_DIR}/ckpt_p1.keras',\n"
    "                                       monitor='val_accuracy', save_best_only=True, verbose=1),\n"
    "]\n"
    "print('PHASE 1 - Training head only (backbone frozen) with Focal Loss')\n"
    "history_p1 = model.fit(\n"
    "    train_ds, validation_data=val_ds,\n"
    "    epochs=EPOCHS_P1, class_weight=class_weight_dict, callbacks=cb1\n"
    ")"
))

# ── CELL 16 ─────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 16 - Phase 1 Training Curves\n"
    "def plot_history(h, title, path):\n"
    "    fig, (a1, a2) = plt.subplots(1, 2, figsize=(14, 5))\n"
    "    a1.plot(h.history['accuracy'], label='Train', lw=2)\n"
    "    a1.plot(h.history['val_accuracy'], label='Val', lw=2)\n"
    "    a1.set_title(f'{title} - Accuracy'); a1.legend(); a1.grid(alpha=0.3)\n"
    "    a2.plot(h.history['loss'], label='Train', lw=2)\n"
    "    a2.plot(h.history['val_loss'], label='Val', lw=2)\n"
    "    a2.set_title(f'{title} - Loss'); a2.legend(); a2.grid(alpha=0.3)\n"
    "    plt.tight_layout(); plt.savefig(path, dpi=150); plt.show()\n"
    "plot_history(history_p1, 'Phase 1 (Frozen backbone + Focal Loss)', f'{OUTPUT_DIR}/phase1_curves.png')\n"
    "p1_best = max(history_p1.history['val_accuracy'])\n"
    "print(f'Phase 1 best val accuracy: {p1_best*100:.1f}%')"
))

# ── CELL 17 ─────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 17 - Phase 2: Fine-Tune Top Backbone Layers\n"
    "# EfficientNetB0 has fewer total layers than V2-S, so unfreeze top 20 (not 50).\n"
    "# Unfreezing too many layers on a small dataset causes overfitting.\n"
    "backbone.trainable = True\n"
    "for layer in backbone.layers[:-20]:\n"
    "    layer.trainable = False\n"
    "model.compile(\n"
    "    optimizer=tf.keras.optimizers.Adam(LR_P2),\n"
    "    loss=focal_loss(FOCAL_LOSS_GAMMA),\n"
    "    metrics=['accuracy']\n"
    ")\n"
    "trainable_p2 = sum(tf.size(v).numpy() for v in model.trainable_variables)\n"
    "print(f'Trainable (Phase 2): {trainable_p2:,}  (top 20 backbone layers + head)')\n"
    "cb2 = [\n"
    "    tf.keras.callbacks.EarlyStopping(monitor='val_accuracy', patience=5,\n"
    "                                     restore_best_weights=True, verbose=1),\n"
    "    tf.keras.callbacks.ReduceLROnPlateau(monitor='val_loss', factor=0.5,\n"
    "                                         patience=3, min_lr=1e-7, verbose=1),\n"
    "    tf.keras.callbacks.ModelCheckpoint(f'{OUTPUT_DIR}/ckpt_p2.keras',\n"
    "                                       monitor='val_accuracy', save_best_only=True, verbose=1),\n"
    "]\n"
    "print('PHASE 2 - Fine-tuning top 20 backbone layers (LR=5e-6, stops early if degrading)')\n"
    "history_p2 = model.fit(\n"
    "    train_ds, validation_data=val_ds,\n"
    "    epochs=EPOCHS_P2, class_weight=class_weight_dict, callbacks=cb2\n"
    ")"
))

# ── CELL 18 ─────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 18 - Phase 2 Training Curves\n"
    "plot_history(history_p2, 'Phase 2 (Fine-tuning + Focal Loss)', f'{OUTPUT_DIR}/phase2_curves.png')\n"
    "p2_best = max(history_p2.history['val_accuracy'])\n"
    "print(f'Phase 1: {p1_best*100:.1f}%  ->  Phase 2: {p2_best*100:.1f}%  (+{(p2_best-p1_best)*100:.1f}%)')"
))

# ── CELL 19 ─────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 19 - Evaluate on Held-Out Test Set (with Test Time Augmentation)\n"
    "# TTA: make TTA_STEPS predictions per image with random augmentation, average softmax scores.\n"
    "# Typically adds +3-8% accuracy at zero training cost.\n"
    "TTA_STEPS = 5\n"
    "\n"
    "def tta_predict(model, dataset, n_steps):\n"
    "    \"\"\"Average n_steps augmented predictions per image.\"\"\"\n"
    "    # Collect all raw images and labels from the dataset\n"
    "    all_imgs, all_lbls = [], []\n"
    "    for imgs, lbls in dataset:\n"
    "        all_imgs.append(imgs.numpy())\n"
    "        all_lbls.append(lbls.numpy())\n"
    "    all_imgs = np.concatenate(all_imgs, axis=0)  # [N, H, W, 3]\n"
    "    all_lbls = np.concatenate(all_lbls, axis=0)  # [N]\n"
    "\n"
    "    # Accumulate softmax scores across TTA steps\n"
    "    accumulated = np.zeros((len(all_imgs), NUM_CLASSES), dtype=np.float32)\n"
    "    for step in range(n_steps):\n"
    "        # Apply same augmentation as training for each TTA step\n"
    "        aug_imgs = []\n"
    "        for img in all_imgs:\n"
    "            t = tf.constant(img)\n"
    "            t = tf.image.random_flip_left_right(t)\n"
    "            t = tf.image.random_flip_up_down(t)\n"
    "            k = tf.random.uniform([], 0, 4, tf.int32)\n"
    "            t = tf.image.rot90(t, k)\n"
    "            t = tf.image.random_brightness(t, 0.15)\n"
    "            t = tf.clip_by_value(t, 0.0, 255.0)\n"
    "            aug_imgs.append(t.numpy())\n"
    "        aug_batch = np.array(aug_imgs, dtype=np.float32)\n"
    "        probs = model.predict(aug_batch, verbose=0, batch_size=BATCH_SIZE)\n"
    "        accumulated += probs\n"
    "        print(f'  TTA step {step+1}/{n_steps} done')\n"
    "\n"
    "    avg_probs = accumulated / n_steps\n"
    "    preds = np.argmax(avg_probs, axis=1)\n"
    "    confs = np.max(avg_probs, axis=1)\n"
    "    return preds, all_lbls, confs\n"
    "\n"
    "print(f'Running TTA evaluation ({TTA_STEPS} augmented passes per image)...')\n"
    "all_preds, all_true, all_confs = tta_predict(model, test_ds, TTA_STEPS)\n"
    "test_acc = np.mean(all_preds == all_true)\n"
    "print(f'\\nTest Accuracy (TTA x{TTA_STEPS}): {test_acc*100:.1f}%')\n"
    "present       = sorted(set(all_true))\n"
    "present_names = [WOUND_LABELS[i] for i in present]\n"
    "print(classification_report(all_true, all_preds,\n"
    "                             labels=present, target_names=present_names, digits=3))\n"
    "missing = [WOUND_LABELS[i] for i in range(NUM_CLASSES) if i not in present]\n"
    "if missing: print(f'Not in test set (too few images): {missing}')"
))

# ── CELL 20 ─────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 20 - Confusion Matrix\n"
    "cm     = confusion_matrix(all_true, all_preds, labels=present)\n"
    "cm_pct = cm.astype(float) / (cm.sum(axis=1, keepdims=True) + 1e-9) * 100\n"
    "plt.figure(figsize=(12, 10))\n"
    "sns.heatmap(cm_pct, annot=True, fmt='.1f',\n"
    "            xticklabels=present_names, yticklabels=present_names,\n"
    "            cmap='Blues', linewidths=0.5, vmin=0, vmax=100)\n"
    "plt.title('Confusion Matrix - % of True Class (Focal Loss v2)', fontweight='bold')\n"
    "plt.xlabel('Predicted'); plt.ylabel('True')\n"
    "plt.xticks(rotation=45, ha='right')\n"
    "plt.tight_layout()\n"
    "plt.savefig(f'{OUTPUT_DIR}/confusion_matrix.png', dpi=150)\n"
    "plt.show()\n"
    "print('Per-class accuracy:')\n"
    "for i, name in enumerate(present_names):\n"
    "    bar = '#' * int(cm_pct[i, i] / 5)\n"
    "    print(f'  {name:<10}: {cm_pct[i,i]:5.1f}%  {bar}')"
))

# ── CELL 21 ─────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 21 - Per-Class Confidence Analysis\n"
    "# Shows the average confidence and correct-prediction confidence per class.\n"
    "# Use this to decide the CONFIDENCE_THRESHOLD for the Flutter app.\n"
    "# Low confidence on a prediction -> trigger 'Specialist review recommended'\n"
    "\n"
    "fig, axes = plt.subplots(2, 4, figsize=(18, 9))\n"
    "threshold_suggestions = {}\n"
    "for class_id, ax in zip(range(NUM_CLASSES), axes.flatten()):\n"
    "    mask     = all_true == class_id\n"
    "    if mask.sum() == 0:\n"
    "        ax.set_title(f'{WOUND_LABELS[class_id]}\\n(not in test set)', color='gray')\n"
    "        ax.axis('off')\n"
    "        continue\n"
    "    c_confs   = all_confs[mask]\n"
    "    c_correct = (all_preds[mask] == class_id)\n"
    "    # Plot confidence distributions: correct vs wrong\n"
    "    if c_correct.sum() > 0:\n"
    "        ax.hist(c_confs[c_correct],  bins=10, alpha=0.7, color='green', label='Correct')\n"
    "    if (~c_correct).sum() > 0:\n"
    "        ax.hist(c_confs[~c_correct], bins=10, alpha=0.7, color='red',   label='Wrong')\n"
    "    acc   = c_correct.mean() * 100\n"
    "    m_conf = c_confs.mean() * 100\n"
    "    # Suggest threshold = 10th percentile of correct confidences (if any)\n"
    "    if c_correct.sum() > 0:\n"
    "        thr = float(np.percentile(c_confs[c_correct], 10))\n"
    "    else:\n"
    "        thr = 0.5\n"
    "    threshold_suggestions[WOUND_LABELS[class_id]] = round(thr, 2)\n"
    "    ax.axvline(thr, color='blue', linestyle='--', linewidth=1.5, label=f'Thr={thr:.2f}')\n"
    "    ax.set_title(f'{WOUND_LABELS[class_id]}\\nAcc={acc:.0f}%  AvgConf={m_conf:.0f}%')\n"
    "    ax.set_xlabel('Confidence'); ax.set_ylabel('Count')\n"
    "    ax.legend(fontsize=7); ax.grid(alpha=0.3)\n"
    "plt.suptitle('Per-Class Confidence Distribution\\n(blue dashed = suggested threshold)',\n"
    "             fontweight='bold', fontsize=13)\n"
    "plt.tight_layout()\n"
    "plt.savefig(f'{OUTPUT_DIR}/confidence_analysis.png', dpi=150)\n"
    "plt.show()\n"
    "print('Suggested per-class thresholds (10th percentile of correct predictions):')\n"
    "for lbl, thr in threshold_suggestions.items():\n"
    "    concern = '  <- consider specialist flag' if thr < 0.55 else ''\n"
    "    print(f'  {lbl}: {thr:.2f}{concern}')"
))

# ── CELL 22 ─────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 22 - Convert to TFLite\n"
    "# Input:  float32 [1, 224, 224, 3]  pixels 0-255  NHWC\n"
    "# Output: float32 [1, 8]            softmax probabilities\n"
    "# EfficientNetV2 uses standard ops only - NO SELECT_TF_OPS needed\n"
    "print('Converting to TFLite...')\n"
    "converter = tf.lite.TFLiteConverter.from_keras_model(model)\n"
    "converter.optimizations = [tf.lite.Optimize.DEFAULT]\n"
    "tflite_model = converter.convert()\n"
    "tflite_path  = f'{OUTPUT_DIR}/wound_classifier.tflite'\n"
    "with open(tflite_path, 'wb') as f:\n"
    "    f.write(tflite_model)\n"
    "size_mb = len(tflite_model) / (1024 * 1024)\n"
    "print(f'Saved: {tflite_path}  ({size_mb:.1f} MB)')"
))

# ── CELL 23 ─────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 23 - Verify TFLite Model\n"
    "interp = tf.lite.Interpreter(model_path=tflite_path)\n"
    "interp.allocate_tensors()\n"
    "inp_d = interp.get_input_details()[0]\n"
    "out_d = interp.get_output_details()[0]\n"
    "print(f'Input  : shape={inp_d[\"shape\"]}  dtype={inp_d[\"dtype\"]}')\n"
    "print(f'Output : shape={out_d[\"shape\"]}  dtype={out_d[\"dtype\"]}')\n"
    "dummy = np.random.uniform(0, 255, (1, IMG_SIZE, IMG_SIZE, 3)).astype(np.float32)\n"
    "interp.set_tensor(inp_d['index'], dummy)\n"
    "interp.invoke()\n"
    "result = interp.get_tensor(out_d['index'])\n"
    "print(f'Test output: {result}')\n"
    "print(f'Sum={result.sum():.4f} (should be ~1.0)')\n"
    "print(f'Predicted class: {WOUND_LABELS[np.argmax(result)]} ({result.max()*100:.1f}%)')"
))

# ── CELL 24 ─────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 24 - Save wound_labels.txt\n"
    "labels_path = f'{OUTPUT_DIR}/wound_labels.txt'\n"
    "with open(labels_path, 'w') as f:\n"
    "    f.write('\\n'.join(WOUND_LABELS))\n"
    "print('wound_labels.txt contents:')\n"
    "for i, l in enumerate(WOUND_LABELS):\n"
    "    print(f'  {i}: {l}')"
))

# ── CELL 25 ─────────────────────────────────────────────────────────────
cells.append(c(
    "# CELL 25 - Download Output Files\n"
    "from google.colab import files\n"
    "files.download(tflite_path)\n"
    "files.download(labels_path)\n"
    "files.download(f'{OUTPUT_DIR}/confusion_matrix.png')\n"
    "files.download(f'{OUTPUT_DIR}/confidence_analysis.png')\n"
    "files.download(f'{OUTPUT_DIR}/class_distribution.png')\n"
    "print('Downloads started - check your browser Downloads folder')\n"
    "print()\n"
    "print('Flutter integration steps:')\n"
    "print('  1. Copy wound_classifier.tflite  -> assets/models/')\n"
    "print('  2. Copy wound_labels.txt          -> assets/models/')\n"
    "print('  3. Set analysisMethod = tflite    in ai_config.dart')\n"
    "print('  4. No SELECT_TF_OPS patch needed  (standard EfficientNetV2 ops)')\n"
    "print('  5. Specialist confirm types       : Type_3, Type_4, Type_6')\n"
    "print('  6. Use CONFIDENCE_THRESHOLD from Cell 21 in Flutter inference code')"
))

# ── Write notebook ───────────────────────────────────────────────────────
nb = {
    "nbformat": 4,
    "nbformat_minor": 0,
    "metadata": {
        "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
        "language_info": {"name": "python", "version": "3.10.12"},
        "accelerator": "GPU",
        "colab": {"provenance": [], "gpuType": "T4"}
    },
    "cells": cells
}

out_path = os.path.join(os.path.dirname(__file__), "wound_efficientnetb0_training.ipynb")
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(nb, f, indent=1, ensure_ascii=False)

print(f"Notebook written to {out_path}")
print(f"Cells: {len(cells)}")
