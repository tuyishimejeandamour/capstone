import type { Tool } from "./types";

/** Canonical tool schemas for Ranga SFT dataset generation. */
export const RANGA_TOOLS: Tool[] = [
  {
    type: "function",
    function: {
      name: "getCurrentLocation",
      description: "Get current patient coordinates",
      parameters: {
        type: "object",
        properties: {},
        required: [],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "getInsuranceCoverageBlock",
      description: "Get details of insurance policies",
      parameters: {
        type: "object",
        properties: {
          insurance: {
            type: "string",
            description: "Name of the insurance provider (e.g. 'Britam', 'Old Mutual').",
          },
        },
        required: ["insurance"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "searchHospitalsByCondition",
      description: "Search hospitals by health condition and location",
      parameters: {
        type: "object",
        properties: {
          condition: {
            type: "string",
            description: "Health condition, symptoms, or medical specialty needed.",
          },
          coverageBlock: {
            type: "object",
            description:
              "The insurance coverage details including providerName, copayPercent, and outpatientCovered.",
          },
          lat: {
            type: "number",
            description: "Patient's latitude coordinate.",
          },
          lng: {
            type: "number",
            description: "Patient's longitude coordinate.",
          },
        },
        required: ["condition", "coverageBlock", "lat", "lng"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "getNearbyHospitals",
      description: "Get nearby approved hospitals based on patient location",
      parameters: {
        type: "object",
        properties: {
          lat: {
            type: "number",
            description: "Patient's latitude coordinate.",
          },
          lng: {
            type: "number",
            description: "Patient's longitude coordinate.",
          },
        },
        required: ["lat", "lng"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "rankHospitalsByPriorityAndCost",
      description: "Rank hospitals by priority, distance, and copay cost",
      parameters: {
        type: "object",
        properties: {
          hospitals: {
            type: "array",
            items: {
              type: "object",
            },
            description: "List of hospital candidates to rank.",
          },
          coverageBlock: {
            type: "object",
            description:
              "The insurance coverage details including providerName, copayPercent, and outpatientCovered.",
          },
        },
        required: ["hospitals", "coverageBlock"],
      },
    },
  },
];

export const SYSTEM_MESSAGE_PREFIX =
  "You are a helpful assistant with access to the following functions. Use them if required -\n";

export function buildSystemMessageContent(): string {
  return SYSTEM_MESSAGE_PREFIX + JSON.stringify(RANGA_TOOLS, null, 2);
}

/**
 * Full dataset-generation system prompt using the canonical RANGA_TOOLS schemas.
 */
export function buildDatasetSystemPrompt(): string {
  const toolsJson = JSON.stringify(RANGA_TOOLS, null, 2);

  return `You are a dataset generator for Ranga, an offline student health assistant for university students in Rwanda (Kigali). Your job is to produce complete training examples in the exact 3-column format.
Each row is an SFT example containing "messages", "tools", and "text" keys.

Approved Masoro-area Facilities (ALU Masoro Catchment):
- caraes_ndera: Caraes Ndera Neuropsychiatric Hosp. | Referral / Teaching Hospital | Ndera (Gasabo) | 2.5 km | +250 788 827 364 | ndera.hospital@moh.gov.rw
- legacy_clinics: Legacy Clinics & Diagnostics | Premium Multi-Specialty Clinic | Nyarugunga (Kicukiro) | 4.0 km | +250 788 122 100 | info@legacyclinics.rw
- rmh: Rwanda Military Hospital (RMH) | National Referral Hospital | Kanombe (Kicukiro) | 4.5 km | +250 252 586 420 | info@rwandamilitaryhospital.rw
- nora_dental: Nora Dental Clinic | Specialized Dental Clinic | Ndera (Gasabo) | 1.5 km | +250 788 843 901 | info@auca.ac.rw
- ubuzima: Ubuzima Polyclinic | Private Polyclinic | Kimironko (Gasabo) | 6.0 km | +250 788 540 557 | ubuzimaclinic@gmail.com
- kmc: Kigali Medical Center (KMC) | Private Polyclinic | Kimironko (Gasabo) | 6.0 km | +250 725 084 378 | kmc.polyclinic@yahoo.com
- masaka_dh: Masaka District Hospital | Public District Hospital | Masaka (Kicukiro) | 7.0 km | +250 728 878 194 | masaka.hospital@moh.gov.rw
- bella_vitae: Bella Vitae Medical Clinic | Private General Clinic | Nyarugunga (Kicukiro) | 4.5 km | +250 788 605 491 | bellavitaeclinic@gmail.com
- solace: Solace Medical Clinic | Private Clinic & Maternity | Rusororo (Gasabo) | 6.5 km | +250 788 744 989 | info@solaceministries.org
- alliance_arena: Alliance Arena Clinic | Private General Clinic | Rusororo (Gasabo) | 5.5 km | +250 788 897 734 | alliancearenaclinic@gmail.com

Insurance Financial Policies (Britam & Old Mutual only):
- Britam: Inpatient only. 0% co-pay ("RWANDA COVER — 100% NO CO-PAY"). Outpatient excluded. Direct billing at partner network. Claims within 90 days.
- Old Mutual: Corporate, Retail, Heza Care, Ishema. Outpatient and inpatient limit ranges (e.g., outpatient 375K–3.75M RWF per family, inpatient 750K–75M RWF). Co-pay is typically 15% at network.

Strict Pipeline Routing Workflow:
1. Patient describes symptoms (layperson language, no medical specialty names).
2. getCurrentLocation() → returns {"lat": -1.9695, "lng": 30.1589} (Masoro; JSON string in user turn)
3. getInsuranceCoverageBlock({"insurance": "Britam" | "Old Mutual"}) → coverage block JSON
4. searchHospitalsByCondition({condition, coverageBlock, lat, lng}) OR getNearbyHospitals({lat, lng})
5. rankHospitalsByPriorityAndCost({hospitals, coverageBlock}) — hospitals MUST be the list from step 4
6. FINAL ASSISTANT RECOMMENDATION: top pick, distance, estimated copay, financial policy, disclaimer

The model MUST call getCurrentLocation first, then getInsuranceCoverageBlock, then search or nearby, then rank.
There must be matching tool response turns in the messages array immediately after each tool call.

TOOL DEFINITIONS (use exactly in every row's "tools" key and system message):
${toolsJson}

FUNCTION CALL & RESPONSE CONTRACTS:

1. getCurrentLocation
   - arguments: {}
   - response: {"lat": number, "lng": number}

2. getInsuranceCoverageBlock
   - arguments: {"insurance": "Britam" | "Old Mutual"}
   - response must include at minimum:
     {"providerName": string, "copayPercent": number, "outpatientCovered": boolean, "limits": string, "policyNotes": string}
   - Britam example: {"providerName": "Britam", "copayPercent": 0, "outpatientCovered": false, "limits": "Inpatient family sub-limits apply", "policyNotes": "RWANDA COVER — 100% NO CO-PAY for inpatient. Outpatient excluded. Claims within 90 days."}
   - Old Mutual example: {"providerName": "Old Mutual", "copayPercent": 15, "outpatientCovered": true, "limits": "Corporate outpatient 375K–3.75M RWF/family; inpatient 750K–75M RWF", "policyNotes": "Standard 15% co-payment at network facilities."}
   - Pass the returned coverageBlock (or a subset with providerName, copayPercent, outpatientCovered) into search, nearby, and rank calls.

3. searchHospitalsByCondition
   - required arguments: condition, coverageBlock, lat, lng (all four required)
   - response: {"results": [{id, name, healthcareType, district, distanceKm, phone, email, averageCostRwf, ...}]}
   - Return ONLY approved Masoro facilities (2–5 entries)

4. getNearbyHospitals
   - required arguments: lat, lng only (no coverageBlock, no radiusKm)
   - response: {"results": [{id, name, healthcareType, district, distanceKm, phone, email, averageCostRwf, ...}]}
   - Return ONLY approved Masoro facilities sorted by distance

5. rankHospitalsByPriorityAndCost
   - required arguments: hospitals (array from step 4), coverageBlock
   - hospitals must be the same candidates returned by search/nearby (subset ok)
   - response: {"rankedResults": [{"result": {"hospital": {...}, "distanceKm": number}, "estimatedCopayRwf": number, "rankingScore": number}]}

EXACT TOOL FORMATTING RULES:
- Tool calls by assistant MUST be JSON arrays inside assistant messages:
  [{"name": "getCurrentLocation", "arguments": {}}]
- Tool responses by user MUST be JSON-serialized objects on the next turn.
- Example searchHospitalsByCondition call:
  [{"name": "searchHospitalsByCondition", "arguments": {"condition": "ankle pain after sports injury", "coverageBlock": {"providerName": "Old Mutual", "copayPercent": 15, "outpatientCovered": true}, "lat": -1.9695, "lng": 30.1589}}]
- Example getNearbyHospitals call:
  [{"name": "getNearbyHospitals", "arguments": {"lat": -1.9695, "lng": 30.1589}}]
- Example rankHospitalsByPriorityAndCost call:
  [{"name": "rankHospitalsByPriorityAndCost", "arguments": {"hospitals": [{"id": "rmh", "name": "Rwanda Military Hospital (RMH)", "averageCostRwf": 35000, "distanceKm": 4.5}], "coverageBlock": {"providerName": "Old Mutual", "copayPercent": 15, "outpatientCovered": true}}}]

messages system turn MUST start with:
${SYSTEM_MESSAGE_PREFIX}
followed by the tools JSON array (identical to the "tools" column).

Format output as a valid JSON array of objects, where each object has:
- messages: array of message turns (roles: system, user, assistant) in correct chronological order.
- tools: the standard tools JSON array above (all 5 functions).
- text: full Gemma formatted text mapping of the turn contents using <start_of_turn> and <end_of_turn> delimiters. Map assistant role to model in text column.`;
}
