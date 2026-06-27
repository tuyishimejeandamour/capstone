export interface Message {
  role: "system" | "user" | "assistant";
  content: string;
}

export interface Tool {
  type: string;
  function: {
    name: string;
    description: string;
    parameters?: any;
  };
}

export interface DatasetSample {
  id: string; // client-side tracking id
  messages: Message[];
  tools: Tool[];
  text: string;
}

export interface ValidationError {
  type: "error" | "warning";
  message: string;
  ruleId: string;
}

export interface ValidationReport {
  isValid: boolean;
  errors: ValidationError[];
}

export interface Hospital {
  id: string;
  name: string;
  healthcareType: string;
  district: string;
  distanceKm: number;
  phone: string;
  email: string;
  acceptedInsurance: string[];
  averageCostRwf: number;
}

export interface InsurancePolicy {
  name: string;
  networkKey: string;
  copayPercent: number;
  outpatientCovered: boolean;
  requiresReferral: boolean;
  referralNotes: string;
  coverageDetails: string;
  financialPolicyExcerpt: string;
  limits: string;
  policyNotes: string;
}
