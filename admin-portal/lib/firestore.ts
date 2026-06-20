import { db } from "./firebase";
import { 
  collection, 
  doc, 
  getDocs, 
  getDoc,
  setDoc,
  updateDoc, 
  query, 
  where, 
  orderBy, 
  onSnapshot 
} from "firebase/firestore";

export interface Hospital {
  id: string;
  name: string;
  address: string;
  district: string;
  province: string;
  lat: number;
  lng: number;
  phone?: string;
  type?: string; // "public" | "private"
  acceptedInsurance: string[];
  specialties: string[];
  emergencyUnit: boolean;
  openingHours?: string;
  communityData: {
    averageRating: number;
    ratingCount: number;
    averageCostRwf: number;
    costSubmissionCount: number;
    averageCostByInsurance: Record<string, number>;
    lastAggregatedAt?: string;
  };
  lastUpdated: string;
}

export interface Submission {
  id: string;
  hospitalId: string;
  hospitalName: string;
  studentVerificationCode: string;
  submittedAt: string;
  expiresAt: string;
  type: "rating_only" | "cost_only" | "rating_and_cost";
  rating?: number;
  costPaidRwf?: number;
  insuranceUsed?: string;
  copayPaidRwf?: number;
  visitReason?: string;
  notes?: string;
  status: "pending" | "approved" | "rejected";
  flagged: boolean;
}

export interface ApprovedSubmission {
  id?: string;
  originalSubmissionId: string;
  hospitalId: string;
  approvedBy: string;
  approvedAt: string;
  rating?: number;
  costPaidRwf?: number;
  insuranceUsed?: string;
  copayPaidRwf?: number;
}

// Submissions helpers
export function subscribePendingSubmissions(callback: (submissions: Submission[]) => void) {
  const q = query(
    collection(db, "pending_submissions"), 
    where("status", "==", "pending"), 
    orderBy("submittedAt", "desc")
  );
  return onSnapshot(q, (snapshot) => {
    const submissions: Submission[] = [];
    snapshot.forEach((doc) => {
      submissions.push({ id: doc.id, ...doc.data() } as Submission);
    });
    callback(submissions);
  });
}

export async function approveSubmission(submission: Submission, adminEmail: string) {
  // 1. Create approved submission doc
  const approvedRef = doc(collection(db, "approved_submissions"));
  const approvedData: ApprovedSubmission = {
    originalSubmissionId: submission.id,
    hospitalId: submission.hospitalId,
    approvedBy: adminEmail,
    approvedAt: new Date().toISOString(),
    rating: submission.rating,
    costPaidRwf: submission.costPaidRwf,
    insuranceUsed: submission.insuranceUsed,
    copayPaidRwf: submission.copayPaidRwf
  };
  await setDoc(approvedRef, approvedData);

  // 2. Update pending submission status
  const pendingRef = doc(db, "pending_submissions", submission.id);
  await updateDoc(pendingRef, { status: "approved" });
}

export async function rejectSubmission(submissionId: string) {
  const pendingRef = doc(db, "pending_submissions", submissionId);
  await updateDoc(pendingRef, { status: "rejected" });
}

export async function toggleFlagSubmission(submissionId: string, flagged: boolean) {
  const pendingRef = doc(db, "pending_submissions", submissionId);
  await updateDoc(pendingRef, { flagged });
}

// Hospitals CRUD helpers
export async function getHospitals(): Promise<Hospital[]> {
  const querySnapshot = await getDocs(collection(db, "hospitals"));
  const hospitals: Hospital[] = [];
  querySnapshot.forEach((doc) => {
    hospitals.push({ id: doc.id, ...doc.data() } as Hospital);
  });
  return hospitals;
}

export async function getHospitalById(id: string): Promise<Hospital | null> {
  const docSnap = await getDoc(doc(db, "hospitals", id));
  if (docSnap.exists()) {
    return { id: docSnap.id, ...docSnap.data() } as Hospital;
  }
  return null;
}

export async function saveHospital(hospital: Partial<Hospital> & { id: string }) {
  const hospitalRef = doc(db, "hospitals", hospital.id);
  const data = {
    ...hospital,
    lastUpdated: new Date().toISOString()
  };
  await setDoc(hospitalRef, data, { merge: true });
}
