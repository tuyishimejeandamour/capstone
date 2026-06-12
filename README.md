# Ranga: Offline Student Health Assistant

An offline-first, private-by-design mobile application built with Flutter that runs **Gemma 4 E2B** locally on-device. The app, named **Ranga**, provides personalized health guidance and clinic referrals tailored to the Rwandan health insurance system. It enables students to upload insurance contract documents (PDFs and images) which are parsed and summarized locally using the native vision and text capabilities of the Gemma 4 model.

---

## Table of Contents
1. [Key Features](#key-features)
2. [GitHub Repository](#github-repository)
3. [System Architecture & Hardware "Circuit" Diagram](#system-architecture--hardware-circuit-diagram)
4. [How Ranga Works: Interface Walkthrough](#how-ranga-works-interface-walkthrough)
5. [Environment Setup & Installation](#environment-setup--installation)
6. [Offline Contract Processing Pipeline](#offline-contract-processing-pipeline)
7. [Deployment & Release Plan](#deployment--release-plan)
8. [Performance Benchmarks & Safeguards](#performance-benchmarks--safeguards)
9. [Tech Stack](#tech-stack)
10. [License](#license)

---

## Key Features

- **100% Local Inference**: Runs Google's **Gemma 4 E2B** model via the LiteRT-LM engine. All chat logs, summaries, and personal profile information stay stored securely in a local SQLite database.
- **Rwandan Health Insurance Integration**: Pre-mapped networks and guidelines for:
  - **Mutuelle de Santé (CBHI)** (10% co-pay at public health centers/district hospitals)
  - **RSSB / RAMA** (15% co-pay at certified private/public clinics like King Faisal Hospital)
  - **Military Medical Insurance (MMI)** (10% co-pay at Rwanda Military Hospital)
  - Private providers (Sanlam, Britam, UAP Old Mutual, Radiant)
- **Local Contract Processing**:
  - **PDFs**: Parses text programmatically using native PDF parsing.
  - **Images**: Feeds image bytes directly to Gemma 4's native vision layer for local OCR and benefit extraction.
- **Offline Medical Guidance & Interceptions**: Smartly intercepts local questions (e.g., clinic hours, nearest hospital) to provide fast, deterministic, offline tool lookups.

---

## GitHub Repository

Access the source code, open issues, and submit pull requests here:
👉 **[Ranga GitHub Repository](https://github.com/tuyishimejeandamour/capstone)**

---

## System Architecture & Hardware "Circuit" Diagram

The Mermaid diagram below represents the hardware and software "circuitry" of the **Ranga** application, illustrating the data flow, resource usage, and interaction between the local storage, device hardware, and local AI runtime.

```mermaid
graph TD
    subgraph Mobile Device Hardware
        CPU["CPU (Main Application Logic & Fallback Inference)"]
        GPU["GPU (LiteRT Vulkan/Metal Delegate Acceleration)"]
        RAM["RAM / VRAM (Mixed 2/4/8-bit Quantized Model Weight Cache)"]
        Storage["Internal Storage (gemma-model.litertlm & SQLite DB)"]
    end

    subgraph Ranga Software Stack
        UI["Flutter UI (Setup Screen, Chat Screen, Profile Drawer)"]
        FilePicker["file_picker Plugin"]
        PDFParser["read_pdf_text API"]
        DBHelper["DatabaseHelper (SQLite Profile & Conversations)"]
        GemmaService["GemmaService (Inference Lifecycle Manager)"]
        LiteRT["LiteRT-LM C-API Bindings (flutter_gemma)"]
    end

    %% User Interaction Flow
    UI -->|1. Inputs Profile & Uploads File| FilePicker
    FilePicker -->|2. Reads PDF Path| PDFParser
    FilePicker -->|2. Reads Image Bytes| UI
    
    %% Storage & Database Flow
    UI -->|3. Writes Profile Context| DBHelper
    DBHelper -->|4. Writes to database file| Storage

    %% Model Inference Pipeline
    UI -->|5. Compiles Vision/Text Prompt| GemmaService
    GemmaService -->|6. Requests Inference| LiteRT
    Storage -->|7. Loads .litertlm file| LiteRT
    LiteRT -->|8. Caches weights| RAM
    LiteRT -->|9a. Accelerates execution| GPU
    LiteRT -->|9b. Fallback execution| CPU
    LiteRT -->|10. Streams tokens back| GemmaService
    GemmaService -->|11. Renders tokens real-time| UI
```

---

## How Ranga Works: Interface Walkthrough

Ranga utilizes a modern, glassmorphic dark-pastel aesthetic designed to provide an interactive, reassuring user experience. Below is a detailed walkthrough of how the application operates, referenced against the actual app screenshots.

### Step 1: Onboarding & App Setup (Home Screen)
The home screen serves as the initial portal for first-launch onboarding, introducing the student to Ranga as a 100% offline, private health guide. 

![Home Screen](app/docs/homeScreen.png)

- **Offline Check**: Upon startup, Ranga performs a local storage check. If the model files are missing, it initiates the secure, resumable download of the 2.4 GB `gemma-4-E2B-it.litertlm` file from HuggingFace.
- **Registration Stage**: Users interact with a sliding gesture knob to transition to the registration phase, where they input their name, select a Rwandan insurance plan (Mutuelle, RSSB, MMI, or private providers), and upload their medical insurance card/contract as a PDF or image.

---

### Step 2: Local AI Personalization & Context (Student Profile Sidebar)
Once setup is complete, the student profile drawer provides a persistent interface showing all user context information stored locally in the SQLite database.

![Student Profile Sidebar](app/docs/student%20profile.png)

- **AI-Powered Analysis**: During the final setup warm-up, the local Gemma 4 model reads the uploaded contract file. Using native PDF parsing or image vision projection, the model analyzes the policy and extracts co-payment rates, policy IDs, and benefit limitations.
- **Context Steering**: The resulting benefit summary is displayed inside the scrollable drawer. Ranga automatically appends this summary context to the background system prompt for all subsequent chats, ensuring the local AI is fully aware of their specific policy limitations when answering questions.

---

### Step 3: Private AI Consultations (Consulting Screen)
The consulting screen enables real-time conversations between the student and Ranga, operating completely offline.

![Consulting Screen](app/docs/consultingascreen.png)

- **Performance Bar**: The green bar at the top displays runtime metrics—identifying whether the local model is accelerated by Vulkan/Metal GPU delegates, the token generation rate (e.g. ~52 tok/s), and thermal cooldown alerts.
- **Voice Capabilities**: The interface integrates speech-to-text (STT) and text-to-speech (TTS) engines, allowing students to speak their queries and hear Ranga's guidance read back to them.
- **Rwandan Hospital Matching**: When users query symptoms or hospital availability, Ranga matches the symptoms against local UR clinic resources or suggests the nearest in-network Kigali hospital (e.g., suggesting Kibagabaga Hospital for Mutuelle users, or Legacy Clinics / King Faisal Hospital for RSSB / RAMA).

---

## Environment Setup & Installation

### Prerequisites
1. **Flutter SDK**: `^3.41.0` or higher (compatible with Dart `^3.11.0`)
2. **Android SDK**: API level 26 (Android 8.0) or higher, with USB debugging enabled
3. **Hardware Requirements**: Real Android device with 6+ GB RAM and OpenGL ES 3.2+ or Vulkan support (Emulators do not support GPU acceleration for LiteRT-LM).

### Project Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/tuyishimejeandamour/capstone.git ranga
   cd ranga
   ```

2. **Fetch dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify Flutter Environment**:
   ```bash
   flutter doctor
   ```

4. **Connect Device and Run**:
   ```bash
   # Make sure your Android device is connected via ADB
   flutter run --debug
   ```

---

## Offline Contract Processing Pipeline

The Mermaid diagram below shows the processing pipeline of the contract documents uploaded into **Ranga**.

```mermaid
flowchart TD
    Start([File Selected]) --> Type{File Extension}
    Type -->|PDF| PDFProc[ReadPdfText API calls getPDFtext]
    Type -->|Image| ImgProc[Read file bytes as Uint8List]
    
    PDFProc --> TextOutput[Extracted Text Content]
    ImgProc --> ByteOutput[Image Byte Array]
    
    TextOutput --> PromptBuilder[GemmaService compiles prompt with vision context]
    ByteOutput --> PromptBuilder
    
    PromptBuilder --> Inference[Local Gemma 4 E2B runs local GPU/CPU inference]
    Inference --> Save[SQLite database stores generated benefit summary]
    Save --> End([Summary Ready])
```

---

## Deployment & Release Plan

### Phase 1: Local Testing & Validation
- **Quality Assurance**: Run static analyzer and verify null-safety.
  ```bash
  flutter analyze
  ```
- **Local Profile Cleansing**: Validate that no development credentials or absolute paths are bundled inside assets.

### Phase 2: Production Compilation
1. **Android App Bundle (AAB)**: Create the release bundle optimized for Google Play distribution.
   ```bash
   flutter build appbundle --release
   ```
2. **Android APK Split (Alternative)**: Create device-specific APKs to minimize download sizes (fat APK includes all ABI architectures which increases size).
   ```bash
   flutter build apk --split-per-abi --release
   ```

### Phase 3: Distribution Strategies
- **Google Play Store**: Upload AAB to Closed Testing tracks. Define storage permissions requirements in the console.
- **Model Provisioning Plan**:
  - The initial application bundle size of **Ranga** is small (~25MB).
  - On the first boot, the app displays a beautiful holographic screen prompting a one-time download of the 2.4 GB `gemma-4-E2B-it.litertlm` file from HuggingFace to the local application document storage.
  - The downloader supports resuming interrupted range requests, ensuring reliability over unstable networks.

---

## Performance Benchmarks & Safeguards

| Metrics | Samsung Galaxy S26 Ultra | Google Pixel 9 Pro | Fallback CPU Backend |
|---------|--------------------------|--------------------|----------------------|
| **TTFT (Time To First Token)** | 0.3 seconds | 0.4 seconds | 1.8 seconds |
| **Generation Speed** | 52.1 tokens/sec | 47.5 tokens/sec | 11.2 tokens/sec |
| **Average Memory Footprint** | ~676 MB | ~710 MB | ~1.4 GB |

### Built-in Safeguards
- **Max Generation Token Cap**: Configured to `512` tokens per response to prevent sustained device heating and throttling.
- **System Memory Throttling**: Monitors thermal states and pauses generations if critical device limits are exceeded.
- **GPU-preferred execution**: Prioritizes Vulkan/Metal delegates to minimize CPU cycles and save battery.

---

## Tech Stack

- **Framework**: Flutter (Dart)
- **Local Model**: Google Gemma 4 E2B (`gemma-4-E2B-it` via LiteRT-LM)
- **Database Engine**: SQLite (`sqflite`) for encrypted-ready relational profile storage
- **Animations Package**: `flutter_animate` for smooth onboarding visual micro-interactions
- **Audio processing**: `speech_to_text` and `flutter_tts` for voice interaction loops
- **File System Utils**: `file_picker` & `read_pdf_text`

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
