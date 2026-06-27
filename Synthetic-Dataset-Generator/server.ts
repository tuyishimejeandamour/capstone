import express from "express";
import path from "path";
import { createServer as createViteServer } from "vite";
import { Agent } from "@cursor/sdk";
import dotenv from "dotenv";
import fs from "fs/promises";
import { existsSync } from "fs";
import { buildDatasetSystemPrompt } from "./src/rangaContract.ts";

dotenv.config();

const app = express();
const PORT = 3000;

app.use(express.json({ limit: "50mb" }));

const DATASET_PATH = path.join(process.cwd(), "dataset.json");

// Helper functions to read and write dataset to local json file
async function readDataset(): Promise<any[]> {
  try {
    if (existsSync(DATASET_PATH)) {
      const data = await fs.readFile(DATASET_PATH, "utf-8");
      return JSON.parse(data);
    }
  } catch (error) {
    console.error("Error reading dataset.json:", error);
  }
  return [];
}

async function writeDataset(samples: any[]): Promise<void> {
  await fs.writeFile(DATASET_PATH, JSON.stringify(samples, null, 2), "utf-8");
}

const SYSTEM_PROMPT = buildDatasetSystemPrompt();

// Load SFT dataset from local JSON file
app.get("/api/dataset", async (req, res) => {
  try {
    const samples = await readDataset();
    res.json({ success: true, samples });
  } catch (error: any) {
    console.error("Failed to read dataset:", error);
    res.status(500).json({ success: false, error: error.message || "Failed to read dataset." });
  }
});

// Save SFT dataset to local JSON file
app.post("/api/dataset/save", async (req, res) => {
  try {
    const { samples } = req.body;
    if (!Array.isArray(samples)) {
      return res.status(400).json({ success: false, error: "Invalid samples format. Must be an array." });
    }
    await writeDataset(samples);
    res.json({ success: true });
  } catch (error: any) {
    console.error("Failed to save dataset:", error);
    res.status(500).json({ success: false, error: error.message || "Failed to save dataset." });
  }
});

// Endpoint to generate training dataset samples using Cursor SDK
app.post("/api/dataset/generate", async (req, res) => {
  const { count, insuranceType, pipelineType, customScenario } = req.body;
  const numSamples = Math.max(1, Math.min(20, count || 1));

  const apiKey = process.env.CURSOR_API_KEY;
  if (!apiKey) {
    return res.status(500).json({
      success: false,
      error: "CURSOR_API_KEY is not configured in the server's environment. Please add it to your .env file."
    });
  }

  try {
    const prompt = `Generate exactly ${numSamples} completely independent synthetic SFT training rows for Ranga assistant.
Filter conditions:
- Insurance Focus: ${insuranceType || "Alternate equally between Britam and Old Mutual"}
- Pipeline Focus: ${pipelineType || "Alternate between Condition-search, Nearby-search, and Clinic-info"}
${customScenario ? `- Custom scenario context/keywords to incorporate: ${customScenario}` : ""}

Ensure each row is highly unique, depicting a different student problem (e.g. mental health, pregnancy/maternity, severe emergency, toothache, sports sprain, headache/flu) matching the specific hospital recommendations.
Keep responses completely detailed, following the strict 13+ turns pipeline for hospital searches.
Return exactly a JSON array containing objects with keys "messages", "tools", and "text" as requested. Ensure no markdown formatting or backticks around the json. Only return the valid JSON array directly.

Here is the system prompt and instructions for the task:
${SYSTEM_PROMPT}`;

    const agent = await Agent.create({
      apiKey,
      model: { id: "composer-2" },
      local: { cwd: process.cwd() },
    });

    const run = await agent.send(prompt);
    const result = await run.wait();
    await agent.close();

    if (result.status === "error") {
      throw new Error("Cursor Agent run failed during generation.");
    }

    const text = result.result || "[]";
    const cleanedText = text.replace(/^```json\s*/i, "").replace(/```\s*$/, "").trim();
    const samples = JSON.parse(cleanedText);
    res.json({ success: true, samples });
  } catch (error: any) {
    console.error("Dataset generation error:", error);
    res.status(500).json({ success: false, error: error.message || "Failed to generate samples." });
  }
});

// Endpoint to automatically correct a specific sample using Cursor SDK
app.post("/api/dataset/correct-sample", async (req, res) => {
  const { sample, feedback } = req.body;

  const apiKey = process.env.CURSOR_API_KEY;
  if (!apiKey) {
    return res.status(500).json({
      success: false,
      error: "CURSOR_API_KEY is not configured in the server's environment. Please add it to your .env file."
    });
  }

  try {
    const prompt = `You are a dataset correction engine. Below is a training sample for Ranga.
It might be broken (e.g., incorrect hospital names, skipped tool workflow, out of order tools, or missing financial policy/copay values).
Feedback/Correction request: "${feedback || "Please validate and correct all strict routing workflow rules and approved hospital constraints."}"

Original Sample:
${JSON.stringify(sample, null, 2)}

Correct this sample so that:
1. It strictly adheres to the routing workflow: symptoms -> getCurrentLocation -> getInsuranceCoverageBlock -> searchHospitalsByCondition/getNearbyHospitals -> rankHospitalsByPriorityAndCost -> final recommendation.
2. It uses ONLY the approved facilities list.
3. Tool schemas and required arguments must match exactly:
   - searchHospitalsByCondition: condition, coverageBlock, lat, lng (all required)
   - getNearbyHospitals: lat, lng only (no coverageBlock)
   - coverageBlock includes providerName, copayPercent, outpatientCovered
4. If Old Mutual is used, copay is ~15% of cost. If Britam is used, copay is 0% (inpatient only, outpatient excluded).
5. The "messages" list has matching tool response turns from user.
6. The "text" column mirrors the full turns correctly with <start_of_turn> & <end_of_turn>.

Return the corrected sample in the same structure (keys: messages, tools, text) in a clean JSON format. Ensure no markdown formatting or backticks around the json. Only return the valid JSON object directly.

Here is the system prompt and instructions for the task:
${SYSTEM_PROMPT}`;

    const agent = await Agent.create({
      apiKey,
      model: { id: "composer-2" },
      local: { cwd: process.cwd() },
    });

    const run = await agent.send(prompt);
    const result = await run.wait();
    await agent.close();

    if (result.status === "error") {
      throw new Error("Cursor Agent run failed during correction.");
    }

    const text = result.result || "{}";
    const cleanedText = text.replace(/^```json\s*/i, "").replace(/```\s*$/, "").trim();
    const correctedSample = JSON.parse(cleanedText);
    res.json({ success: true, sample: correctedSample });
  } catch (error: any) {
    console.error("Dataset correction error:", error);
    res.status(500).json({ success: false, error: error.message || "Failed to correct sample." });
  }
});

// Serve frontend assets
async function startServer() {
  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa",
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), 'dist');
    app.use(express.static(distPath));
    app.get('*', (req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on port ${PORT}`);
  });
}

startServer();
