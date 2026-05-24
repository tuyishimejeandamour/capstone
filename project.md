This documentation is structured for an ALU (African Leadership University) final capstone submission. It outlines the development of ALU Health-Voice, a mobile application designed for student wellness using on-device Large Language Models (LLMs) and Reinforcement Learning from Human Feedback (RLHF). [1, 2, 3, 4, 5] 
------------------------------
## ALU Health-Voice: Project Documentation## 1. Introduction## 1.1 Project Context
ALU students in Kigali navigate complex health landscapes with no 24/7 on-campus clinic. Accessing healthcare often requires self-triage before visiting facilities like King Faisal Hospital. [6, 7, 8] 
## 1.2 Problem Statement
Students face high levels of anxiety (40.6%) and depression (38.5%). Existing digital tools often require constant internet access, which can be unreliable, and lack alignment with local health insurance policies like RSSB. [7, 9] 
## 1.3 Objectives

* Develop a mobile-first application using Flutter or React Native.
* Integrate on-device Speech-to-Text for emergency reporting.
* Implement a Small Language Model (SLM) for local triage and insurance navigation.
* Fine-tune the model using RLHF to ensure medically safe and contextually relevant responses. [4, 10, 11, 12, 13, 14, 15] 
* 

------------------------------
## 2. Literature Review Summary
Studies at the University of Rwanda confirm that academic pressure and social isolation significantly contribute to psychological distress. Global research indicates that AI-driven triage can improve emergency response times by 19% compared to manual documentation. On-device deployment is emerging as a critical standard for medical privacy. [16, 17, 18, 19] 
------------------------------
## 3. Methodology & Technical Background## 3.1 Mobile App Architecture
The solution is a standalone mobile application built using Flutter. This allows for a single codebase to support both Android and iOS devices used by the student body. [20, 21] 
## 3.2 Machine Learning Pipeline

   1. Speech Recognition: Uses the Whisper-tiny model (quantized for mobile) to convert student voice recordings into text.
   2. On-Device LLM: Deployment of Phi-3 Mini via MediaPipe LLM Inference to ensure 100% offline functionality and data privacy.
   3. Reinforcement Learning (RLHF):
   * Phase 1 (SFT): Supervised fine-tuning on ALU-specific insurance FAQs and health protocols.
      * Phase 2 (DPO): Direct Preference Optimization using a dataset of "Safe" vs. "Unsafe" medical responses to align the model with safe triage guidelines. [4, 11, 14, 22, 23, 24, 25] 
   
------------------------------
## 4. System Design & Features## 4.1 Key Features

* Voice Symptom Logger: One-tap recording for students in distress.
* Intelligent Triage: Categorizes input into "Self-Care," "Wellness Visit," or "Emergency".
* Insurance Navigator: Queries the local database for RSSB-approved providers in Kigali.
* SOS Panic Button: One-touch dial to the ALU Duty Phone and 112 emergency services. [9, 13, 18, 26, 27] 
* 

## 4.2 System Diagrams

* Use Case: Student $\rightarrow$ Voice Input $\rightarrow$ Local LLM $\rightarrow$ Insurance/Triage Result.
* Data Flow: Local storage only; no health data is sent to external servers. [11, 19] 
* 

------------------------------
## 5. Implementation Plan (Timeline)

* Week 1-4: Literature review and RLHF dataset collection (ALU Insurance & Wellness policies).
* Week 5-8: Model fine-tuning (SFT + DPO) and quantization for mobile.
* Week 9-12: Flutter app development and on-device model integration.
* Week 13-16: Testing with student first-aiders and final documentation. [1, 5, 11, 22, 25, 28] 

------------------------------
## 6. Conclusion & Recommendations
ALU Health-Voice addresses the critical "offline" and "privacy" gaps in student healthcare. Future versions should consider multilingual support for Kinyarwanda and French to increase accessibility. [26, 27] 
------------------------------
Would you like a sample "Use Case Diagram" or the specific "DPO Dataset" structure for your RLHF training?

[1] [https://www.rp.ac.rw](https://www.rp.ac.rw/fileadmin/user_upload/RP/Publications/RP_Guidlines_for_Capstone_Project_Implementation.pdf)
[2] [https://www.scribd.com](https://www.scribd.com/document/956445091/Parts-of-the-Capstone-Project)
[3] [https://huggingface.co](https://huggingface.co/blog/rlhf)
[4] [https://www.youtube.com](https://www.youtube.com/watch?v=qPN_XZcJf_s&t=14)
[5] [https://www.scribd.com](https://www.scribd.com/document/990553378/ai-project-model-final)
[6] [https://dr.ur.ac.rw](https://dr.ur.ac.rw/bitstream/handle/123456789/2133/Dr.%20Prince%20Alain%20KUBWAYO.pdf?sequence=1&isAllowed=y)
[7] [https://rbc.gov.rw](https://rbc.gov.rw/publichealthbulletin/img/rphb_issues/834a8099bbe1d8ba4fda30a0ee5941361714559139.pdf)
[8] [https://dr.ur.ac.rw](https://dr.ur.ac.rw/bitstream/handle/123456789/419/UWAMBAJIMANA%20JOCELYNE.pdf?sequence=1&isAllowed=y)
[9] [https://www.alueducation.com](https://www.alueducation.com/admissions-application-guide/)
[10] [https://www.slideshare.net](https://www.slideshare.net/slideshow/software-engineering-capstone-swe-481-group-4-group-project-phase-5/42987118)
[11] [https://www.youtube.com](https://www.youtube.com/watch?v=Rn6RnynN2TA)
[12] [https://www.youtube.com](https://www.youtube.com/watch?v=TSpxMleSYU8&t=31)
[13] [https://www.ijert.org](https://www.ijert.org/ai-powered-healthcare-chatbot-using-t5-for-query-responses-and-random-forest-for-symptom-based-diagnosis-with-voice-and-text-output)
[14] [https://ieeexplore.ieee.org](https://ieeexplore.ieee.org/document/10698396/)
[15] [https://labelstud.io](https://labelstud.io/blog/create-a-high-quality-rlhf-dataset/)
[16] [https://www.scirp.org](https://www.scirp.org/journal/paperinformation?paperid=116700)
[17] [https://pmc.ncbi.nlm.nih.gov](https://pmc.ncbi.nlm.nih.gov/articles/PMC9243415/)
[18] [https://journals.plos.org](https://journals.plos.org/digitalhealth/article?id=10.1371/journal.pdig.0000406)
[19] [https://pmc.ncbi.nlm.nih.gov](https://pmc.ncbi.nlm.nih.gov/articles/PMC12524231/)
[20] [https://peer.asee.org](https://peer.asee.org/mobile-applications-development-in-senior-design-capstone-courses.pdf)
[21] [https://github.com](https://github.com/aldefy/Capstone-Project)
[22] [https://proceedings.iclr.cc](https://proceedings.iclr.cc/paper_files/paper/2024/file/5a68d05006d5b05dd9463dd9c0219db0-Paper-Conference.pdf)
[23] [https://www.youtube.com](https://www.youtube.com/watch?v=D-MH6YjuIlE&t=3)
[24] [https://colab.research.google.com](https://colab.research.google.com/github/ashworks1706/rlhf-from-scratch/blob/main/tutorial.ipynb)
[25] [https://www.youtube.com](https://www.youtube.com/watch?v=aI8cyr-gH6M&t=65)
[26] [https://www.scribd.com](https://www.scribd.com/document/906053772/Project-1-final-Report-8th-Sem-VERIFIED-2025)
[27] [https://pmc.ncbi.nlm.nih.gov](https://pmc.ncbi.nlm.nih.gov/articles/PMC10699611/)
[28] [https://www.scribd.com](https://www.scribd.com/document/786363396/FINAL-DRAFT-GUIDELINES-FOR-CAPSTONE-PROJECT-IMPLEMENTATION)
