import { Hospital, InsurancePolicy, DatasetSample, ValidationReport, ValidationError } from "./types";
import { RANGA_TOOLS } from "./rangaContract";

export { RANGA_TOOLS };

export const APPROVED_FACILITIES: Hospital[] = [
  {
    id: "caraes_ndera",
    name: "Caraes Ndera Neuropsychiatric Hosp.",
    healthcareType: "Referral / Teaching Hospital",
    district: "Ndera (Gasabo)",
    distanceKm: 2.5,
    phone: "+250 788 827 364",
    email: "ndera.hospital@moh.gov.rw",
    acceptedInsurance: ["britam", "uap"],
    averageCostRwf: 30000
  },
  {
    id: "legacy_clinics",
    name: "Legacy Clinics & Diagnostics",
    healthcareType: "Premium Multi-Specialty Clinic",
    district: "Nyarugunga (Kicukiro)",
    distanceKm: 4.0,
    phone: "+250 788 122 100",
    email: "info@legacyclinics.rw",
    acceptedInsurance: ["britam", "uap"],
    averageCostRwf: 45000
  },
  {
    id: "rmh",
    name: "Rwanda Military Hospital (RMH)",
    healthcareType: "National Referral Hospital",
    district: "Kanombe (Kicukiro)",
    distanceKm: 4.5,
    phone: "+250 252 586 420",
    email: "info@rwandamilitaryhospital.rw",
    acceptedInsurance: ["britam", "uap"],
    averageCostRwf: 35000
  },
  {
    id: "nora_dental",
    name: "Nora Dental Clinic",
    healthcareType: "Specialized Dental Clinic",
    district: "Ndera (Gasabo)",
    distanceKm: 1.5,
    phone: "+250 788 843 901",
    email: "info@auca.ac.rw",
    acceptedInsurance: ["britam", "uap"],
    averageCostRwf: 25000
  },
  {
    id: "ubuzima",
    name: "Ubuzima Polyclinic",
    healthcareType: "Private Polyclinic",
    district: "Kimironko (Gasabo)",
    distanceKm: 6.0,
    phone: "+250 788 540 557",
    email: "ubuzimaclinic@gmail.com",
    acceptedInsurance: ["britam", "uap"],
    averageCostRwf: 20000
  },
  {
    id: "kmc",
    name: "Kigali Medical Center (KMC)",
    healthcareType: "Private Polyclinic",
    district: "Kimironko (Gasabo)",
    distanceKm: 6.0,
    phone: "+250 725 084 378",
    email: "kmc.polyclinic@yahoo.com",
    acceptedInsurance: ["britam", "uap"],
    averageCostRwf: 18000
  },
  {
    id: "masaka_dh",
    name: "Masaka District Hospital",
    healthcareType: "Public District Hospital",
    district: "Masaka (Kicukiro)",
    distanceKm: 7.0,
    phone: "+250 728 878 194",
    email: "masaka.hospital@moh.gov.rw",
    acceptedInsurance: ["britam", "uap"],
    averageCostRwf: 15000
  },
  {
    id: "bella_vitae",
    name: "Bella Vitae Medical Clinic",
    healthcareType: "Private General Clinic",
    district: "Nyarugunga (Kicukiro)",
    distanceKm: 4.5,
    phone: "+250 788 605 491",
    email: "bellavitaeclinic@gmail.com",
    acceptedInsurance: ["britam", "uap"],
    averageCostRwf: 16000
  },
  {
    id: "solace",
    name: "Solace Medical Clinic",
    healthcareType: "Private Clinic & Maternity",
    district: "Rusororo (Gasabo)",
    distanceKm: 6.5,
    phone: "+250 788 744 989",
    email: "info@solaceministries.org",
    acceptedInsurance: ["britam", "uap"],
    averageCostRwf: 22000
  },
  {
    id: "alliance_arena",
    name: "Alliance Arena Clinic",
    healthcareType: "Private General Clinic",
    district: "Rusororo (Gasabo)",
    distanceKm: 5.5,
    phone: "+250 788 897 734",
    email: "alliancearenaclinic@gmail.com",
    acceptedInsurance: ["britam", "uap"],
    averageCostRwf: 17000
  }
];

export const INSURANCE_SCHEMES: InsurancePolicy[] = [
  {
    name: "Britam",
    networkKey: "britam",
    copayPercent: 0,
    outpatientCovered: false,
    requiresReferral: false,
    referralNotes: "Direct billing at partner private clinics and pharmacies.",
    coverageDetails: "Inpatient only; outpatient excluded. Direct coverage for private inpatient packages.",
    financialPolicyExcerpt:
      "0% co-pay on referenced inpatient schedule; member/employer pays above family sub-limits; claims within 90 days.",
    limits: "Inpatient family sub-limits apply (overall limit per family)",
    policyNotes:
      "100% inpatient coverage (0% copay). Outpatient strictly excluded. 90-day claim submission deadline with original documents.",
  },
  {
    name: "Old Mutual",
    networkKey: "uap",
    copayPercent: 15,
    outpatientCovered: true,
    requiresReferral: false,
    referralNotes: "Direct access to premium partner hospitals with pre-authorization for inpatient care.",
    coverageDetails: "Premium private coverage across partner clinics; plan-dependent limits.",
    financialPolicyExcerpt:
      "Corporate inpatient family limit 750K–75M RWF; outpatient 375K–3.75M RWF/family; ~15% co-pay at network.",
    limits: "Corporate inpatient limit (750k - 75M RWF); corporate outpatient (375k - 3.75M RWF)",
    policyNotes:
      "Plan class & benefit limits based. Direct billing at partner network with a standard 15% co-payment.",
  },
];

// Helper to check and validate SFT synthetic data lines in real-time
export function validateSample(sample: DatasetSample): ValidationReport {
  const errors: ValidationError[] = [];

  // Check required keys
  if (!sample.messages || !Array.isArray(sample.messages)) {
    errors.push({ type: "error", message: "Missing or invalid 'messages' array.", ruleId: "messages-missing" });
    return { isValid: false, errors };
  }

  // Look for system prompt structure
  const systemMsg = sample.messages.find(m => m.role === "system");
  if (!systemMsg) {
    errors.push({ type: "warning", message: "Missing 'system' prompt in SFT messages.", ruleId: "system-missing" });
  }

  // Parse and extract the exact order of tool calls in the sequence
  const toolCalls: string[] = [];
  sample.messages.forEach((msg) => {
    if (msg.role === "assistant" && msg.content.trim().startsWith("[")) {
      try {
        const parsed = JSON.parse(msg.content);
        if (Array.isArray(parsed)) {
          parsed.forEach(call => {
            if (call.name) toolCalls.push(call.name);
          });
        }
      } catch (e) {
        // Not a standard tool array format or JSON parse failed
      }
    }
  });

  // Verify strict pipeline routing workflow: getCurrentLocation -> getInsuranceCoverageBlock -> search/nearby -> rank
  if (toolCalls.includes("rankHospitalsByPriorityAndCost")) {
    const rankIndex = toolCalls.indexOf("rankHospitalsByPriorityAndCost");
    
    // Check that search/nearby happens before rank
    const searchIndex = toolCalls.indexOf("searchHospitalsByCondition");
    const nearbyIndex = toolCalls.indexOf("getNearbyHospitals");
    
    if (searchIndex === -1 && nearbyIndex === -1) {
      errors.push({
        type: "error",
        message: "Pipeline violation: rankHospitalsByPriorityAndCost called without prior search/nearby query.",
        ruleId: "rank-before-search"
      });
    } else {
      const earliestSearch = Math.min(
        searchIndex === -1 ? Infinity : searchIndex,
        nearbyIndex === -1 ? Infinity : nearbyIndex
      );
      if (rankIndex < earliestSearch) {
        errors.push({
          type: "error",
          message: "Pipeline violation: rankHospitalsByPriorityAndCost must occur AFTER search/nearby.",
          ruleId: "rank-sequence"
        });
      }
    }

    // Check location & insurance sequences
    const locIndex = toolCalls.indexOf("getCurrentLocation");
    const insIndex = toolCalls.indexOf("getInsuranceCoverageBlock");
    
    if (locIndex === -1) {
      errors.push({ type: "error", message: "Strict workflow missing 'getCurrentLocation' step.", ruleId: "missing-location" });
    }
    if (insIndex === -1) {
      errors.push({ type: "error", message: "Strict workflow missing 'getInsuranceCoverageBlock' step.", ruleId: "missing-insurance" });
    }
    
    if (locIndex !== -1 && insIndex !== -1 && insIndex < locIndex) {
      errors.push({
        type: "error",
        message: "Pipeline violation: getInsuranceCoverageBlock must never precede getCurrentLocation.",
        ruleId: "insurance-before-location"
      });
    }
  }

  // Look for forbidden/unapproved hospitals
  const approvedNames = APPROVED_FACILITIES.map(h => h.name.toLowerCase());
  const approvedIds = APPROVED_FACILITIES.map(h => h.id);

  let usesForbiddenHospital = false;
  let hasValidApprovedHospital = false;

  sample.messages.forEach(msg => {
    const contentLower = msg.content.toLowerCase();
    
    // Check for standard unapproved major hospitals
    const forbidden = ["king faisal", "chuk", "chub", "kibagabaga", "faisal hospital"];
    forbidden.forEach(f => {
      if (contentLower.includes(f)) {
        usesForbiddenHospital = true;
        errors.push({
          type: "error",
          message: `Forbidden facility usage detected: Found references to '${f}'. Only the 10 approved Masoro catchment facilities are allowed.`,
          ruleId: "forbidden-facility"
        });
      }
    });

    // Check if at least one approved Masoro facility is recommended or parsed
    APPROVED_FACILITIES.forEach(f => {
      if (contentLower.includes(f.name.toLowerCase())) {
        hasValidApprovedHospital = true;
      }
    });
  });

  if (!hasValidApprovedHospital && toolCalls.length > 0) {
    errors.push({
      type: "warning",
      message: "Approved facility reference: No approved Masoro-area hospital names found in assistant recommendations.",
      ruleId: "no-approved-facility"
    });
  }

  // Check matching tool responses (every tool call must have a user response)
  let callCount = 0;
  let responseCount = 0;
  sample.messages.forEach((msg, idx) => {
    if (msg.role === "assistant" && msg.content.trim().startsWith("[")) {
      callCount++;
      // Next turn should ideally be a user response
      const nextMsg = sample.messages[idx + 1];
      if (nextMsg && nextMsg.role === "user") {
        responseCount++;
      }
    }
  });

  if (callCount > responseCount) {
    errors.push({
      type: "error",
      message: "Unbalanced messaging turns: Tool calls found without a following user-role tool response.",
      ruleId: "unbalanced-turns"
    });
  }

  // Tool argument contract checks
  sample.messages.forEach((msg) => {
    if (msg.role !== "assistant" || !msg.content.trim().startsWith("[")) return;
    try {
      const calls = JSON.parse(msg.content);
      if (!Array.isArray(calls)) return;
      calls.forEach((call: { name?: string; arguments?: Record<string, unknown> }) => {
        const args = call.arguments || {};
        if (call.name === "searchHospitalsByCondition") {
          if (!args.condition || !args.coverageBlock) {
            errors.push({
              type: "error",
              message: "searchHospitalsByCondition requires condition and coverageBlock arguments.",
              ruleId: "search-required-args"
            });
          }
          if (args.lat === undefined || args.lng === undefined) {
            errors.push({
              type: "error",
              message: "searchHospitalsByCondition requires lat and lng arguments.",
              ruleId: "search-lat-lng"
            });
          }
        }
        if (call.name === "getNearbyHospitals") {
          if (args.lat === undefined || args.lng === undefined) {
            errors.push({
              type: "error",
              message: "getNearbyHospitals requires lat and lng arguments.",
              ruleId: "nearby-lat-lng"
            });
          }
        }
        if (call.name === "rankHospitalsByPriorityAndCost") {
          if (!args.hospitals || !args.coverageBlock) {
            errors.push({
              type: "error",
              message: "rankHospitalsByPriorityAndCost requires hospitals and coverageBlock arguments.",
              ruleId: "rank-required-args"
            });
          }
        }
      });
    } catch {
      // ignore
    }
  });

  // Check Gemma tokens format in 'text' column
  if (sample.text) {
    if (!sample.text.includes("<start_of_turn>") || !sample.text.includes("<end_of_turn>")) {
      errors.push({
        type: "warning",
        message: "Missing Gemma chat template formatting delimiters (<start_of_turn> / <end_of_turn>) in 'text' field.",
        ruleId: "gemma-format"
      });
    }
  } else {
    errors.push({ type: "error", message: "Missing 'text' column required for Gemma fine-tuning data.", ruleId: "text-missing" });
  }

  return {
    isValid: errors.filter(e => e.type === "error").length === 0,
    errors
  };
}
