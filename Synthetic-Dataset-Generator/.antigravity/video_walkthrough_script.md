# Capstone Walkthrough Video Script & Outline

**Target Duration:** ~5 Minutes  
**Audience:** Capstone Examiners & Academic Supervisor  
**Core Focus:** Demonstrating offline AI execution, local contract extraction, local database routing algorithms, and hardware telemetry.

---

## Video Outline & Timeline

| Time | Scene / Focus | Visual Focus | Narrative Focus |
|---|---|---|---|
| **0:00 - 0:45** | **Introduction & Architecture** | Splash screen & Mermaid circuit diagram | Introducing **Ranga**, the offline insurance-aware assistant. Emphasize that all logic is 100% on-device. |
| **0:45 - 1:30** | **First Launch & Model Setup** | Welcome screen to download progress bar | Verifying local `.litertlm` model presence and downloading/loading model weights. |
| **1:30 - 2:30** | **Contract Parsing & Sidebar UI** | Document upload interaction & student profile sidebar | Demonstrating local OCR and vision processing of insurance PDF/Image cards to extract policies. |
| **2:30 - 3:45** | **Live Routing & Algorithm Demos** | Text query interaction & suggested hospital cards | Simulating Mutuelle (referrals), RSSB (copays), and Specialist (bypass) query scenarios. |
| **3:45 - 4:30** | **Performance & Safety Telemetry** | Telemetry bar and terminal debug logs | Highlighting GPU delegate acceleration (tok/s), RAM bounds, and PerformanceMonitor thermal safety. |
| **4:30 - 5:00** | **Conclusion** | Final repo view & README references | Summarizing objectives achieved, DPO safety validation, and wrapping up. |

---

## Detailed Script & Presenter Cues

### Part 1: Introduction & Architecture (0:00 - 0:45)
*   **Visual:** Show the mobile phone running the Ranga welcome screen. Hover mouse or cursor on the logo.
*   **Narrative (Speaking):**
    > *"Hello everyone. Today, I am demonstrating **Ranga**, an offline-first, private-by-design mobile health companion built with Flutter for students in Kigali. Many students face significant financial risks due to complex medical insurance networks. Ranga runs Google’s Gemma 4 E2B model fully on-device to classify queries, map them to local hospitals, and estimate out-of-pocket costs without using the internet."*

---

### Part 2: First Launch & Model Setup (0:45 - 1:30)
*   **Visual:** Tap 'Get Started'. Show the app transitioning to the Model Downloading Screen (`app/docs/downlaoding.png`).
*   **Narrative (Speaking):**
    > *"On first launch, Ranga checks if the local model weights are present. If missing, it initiates a secure, resumable download of the 2.4 GB `gemma-4-E2B-it.litertlm` file from HuggingFace. Once downloaded, the application initializes the LiteRT-LM framework. This ensures that personal query data never leaves the student's device."*

---

### Part 3: Contract Parsing & Student Profile Sidebar (1:30 - 2:30)
*   **Visual:** Show the onboarding screen, choose "RSSB / RAMA", and upload a sample medical contract document. Slide open the student profile drawer (`app/docs/student profile.png`).
*   **Narrative (Speaking):**
    > *"Here, we upload a health insurance card or contract. The local Gemma model parses the image bytes directly on-device using its vision capabilities. In the sidebar, we can see the extracted metrics: a 15% co-pay rate for RSSB, policy limits, and covered clinics. This summary context is automatically injected into subsequent chat prompts to customize recommendations."*

---

### Part 4: Live Routing & Algorithm Demos (2:30 - 3:45)
*   **Visual:** Type: *"I need a general consultation. My stomach hurts."* Show the immediate recommendation card directing to Kibagabaga Hospital.
*   **Narrative (Speaking):**
    > *"Now, let's look at the routing logic. In this first test case, the student has a Mutuelle de Santé profile. The app recommends Kibagabaga Hospital but warns that a referral letter is required from a local health center to cover the bill. 
    > Next, let's type: 'I need dental care at King Faisal Hospital.' Because this is an RSSB user, the app approves the direct route and estimates the co-pay as 15% of the baseline cost using our SQLite database. 
    > If a user enters a chronic illness, the system triggers the Referral Bypass Logic, routing them directly to CHUK without a primary referral step."*

---

### Part 5: Performance & Safety Telemetry (3:45 - 4:30)
*   **Visual:** Point to the telemetry state bar at the top of the consulting screen (`app/docs/consultingascreen.png`). Show the token output rate and memory usage.
*   **Narrative (Speaking):**
    > *"Ranga uses hardware acceleration delegates like Vulkan on Android to run the model. On a standard mobile device, we achieve a generation speed of over 18 tokens per second. We have built-in safeguards to prevent thermal throttling: our PerformanceMonitor class halts model inference if continuous generation exceeds 120 seconds, ensuring the phone stays cool."*

---

### Part 6: Conclusion (4:30 - 5:00)
*   **Visual:** Display the repository's main page showing `capstone_evaluation_report.md`.
*   **Narrative (Speaking):**
    > *"To conclude, Ranga achieves a 88.5% Functional Pass Rate through Direct Preference Optimization. Our results prove that small language models can perform complex administrative healthcare tasks locally on cheap hardware. Thank you for your time."*
