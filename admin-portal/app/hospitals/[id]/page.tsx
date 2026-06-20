"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { Hospital, getHospitalById } from "../../../lib/firestore";
import { db } from "../../../lib/firebase";
import { collection, query, where, getDocs } from "firebase/firestore";
import Link from "next/link";

interface HistoricalReview {
  id: string;
  approvedAt: string;
  rating?: number;
  costPaidRwf?: number;
  insuranceUsed?: string;
  copayPaidRwf?: number;
  approvedBy?: string;
  visitReason?: string;
  notes?: string;
}

export default function HospitalDetailPage() {
  const params = useParams();
  const router = useRouter();
  const hospitalId = params.id as string;

  const [hospital, setHospital] = useState<Hospital | null>(null);
  const [reviews, setReviews] = useState<HistoricalReview[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!hospitalId) return;

    const fetchHospitalAndReviews = async () => {
      setLoading(true);
      try {
        const hData = await getHospitalById(hospitalId);
        if (!hData) {
          alert("Hospital not found.");
          router.push("/hospitals");
          return;
        }
        setHospital(hData);

        const qApproved = query(
          collection(db, "approved_submissions"),
          where("hospitalId", "==", hospitalId)
        );
        const approvedSnap = await getDocs(qApproved);

        const qPending = query(
          collection(db, "pending_submissions"),
          where("hospitalId", "==", hospitalId),
          where("status", "==", "approved")
        );
        const pendingSnap = await getDocs(qPending);
        const pendingMap = new Map<string, any>();
        pendingSnap.forEach((doc) => {
          pendingMap.set(doc.id, doc.data());
        });

        const items: HistoricalReview[] = [];
        approvedSnap.forEach((doc) => {
          const data = doc.data();
          const origId = data.originalSubmissionId;
          const pendingData = pendingMap.get(origId) || {};

          items.push({
            id: doc.id,
            approvedAt: data.approvedAt,
            rating: data.rating,
            costPaidRwf: data.costPaidRwf,
            insuranceUsed: data.insuranceUsed,
            copayPaidRwf: data.copayPaidRwf,
            approvedBy: data.approvedBy,
            visitReason: pendingData.visitReason || "",
            notes: pendingData.notes || ""
          });
        });

        items.sort((a, b) => new Date(b.approvedAt).getTime() - new Date(a.approvedAt).getTime());
        setReviews(items);
      } catch (e) {
        console.error("Error fetching detail data:", e);
      } finally {
        setLoading(false);
      }
    };

    fetchHospitalAndReviews();
  }, [hospitalId, router]);

  if (loading) {
    return <div style={{ padding: "2rem", color: "var(--text-secondary)" }}>Loading hospital metrics...</div>;
  }

  if (!hospital) {
    return null;
  }

  const insuranceOptions = ["mutuelle", "rssb", "mmi", "sanlam", "britam", "uap", "radiant"];

  const renderStars = (rating?: number) => {
    if (!rating) return "-";
    return (
      <span className="rating-stars">
        {"★".repeat(rating)}
        {"☆".repeat(5 - rating)}
      </span>
    );
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <Link href="/hospitals" className="btn btn-secondary" style={{ marginBottom: "1rem" }}>
            ← Back to Listings
          </Link>
          <h1 className="page-title">{hospital.name}</h1>
          <p className="page-subtitle">{hospital.address} · {hospital.district}, {hospital.province}</p>
        </div>
        <div style={{ textAlign: "right" }}>
          <span className={`badge ${hospital.type === "private" ? "badge-info" : "badge-success"}`} style={{ fontSize: "1rem", padding: "0.4rem 0.8rem" }}>
            {hospital.type?.toUpperCase()}
          </span>
          <div style={{ color: "var(--text-secondary)", fontSize: "0.85rem", marginTop: "0.5rem" }}>
            Last Updated: {new Date(hospital.lastUpdated).toLocaleDateString()}
          </div>
        </div>
      </div>

      <div className="grid-cols-2">
        <div className="card">
          <h2 className="card-title">Hospital Profile</h2>
          <div style={{ display: "grid", gap: "1rem" }}>
            <div>
              <span style={{ color: "var(--text-secondary)", fontSize: "0.85rem" }}>Contact Phone</span>
              <p style={{ fontWeight: 600 }}>{hospital.phone || "No contact number listed"}</p>
            </div>
            <div>
              <span style={{ color: "var(--text-secondary)", fontSize: "0.85rem" }}>Opening Hours</span>
              <p style={{ fontWeight: 600 }}>⏰ {hospital.openingHours || "N/A"}</p>
            </div>
            <div>
              <span style={{ color: "var(--text-secondary)", fontSize: "0.85rem" }}>ER Emergency Unit</span>
              <p style={{ fontWeight: 600 }}>{hospital.emergencyUnit ? "✅ Dedicated Emergency Service" : "❌ No dedicated emergency ER"}</p>
            </div>
            <div>
              <span style={{ color: "var(--text-secondary)", fontSize: "0.85rem" }}>Specialties</span>
              <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap", marginTop: "0.25rem" }}>
                {hospital.specialties.map((s) => (
                  <span key={s} className="badge badge-info" style={{ fontSize: "0.75rem" }}>{s}</span>
                ))}
              </div>
            </div>
            <div>
              <span style={{ color: "var(--text-secondary)", fontSize: "0.85rem" }}>Geographic Coordinates</span>
              <p style={{ fontFamily: "monospace", fontSize: "0.9rem" }}>Lat: {hospital.lat} / Lng: {hospital.lng}</p>
            </div>
          </div>
        </div>

        <div className="card">
          <h2 className="card-title">📊 Community Health Analytics</h2>
          <div style={{ display: "flex", gap: "2rem", marginBottom: "1.5rem" }}>
            <div style={{ flex: 1, textAlign: "center", borderRight: "1px solid var(--border-color)" }}>
              <div style={{ fontSize: "2.5rem", fontWeight: "bold", color: "var(--warning)" }}>
                ⭐ {hospital.communityData?.averageRating?.toFixed(1) || "0.0"}
              </div>
              <div style={{ fontSize: "0.8rem", color: "var(--text-secondary)" }}>
                Based on {hospital.communityData?.ratingCount || 0} reviews
              </div>
            </div>
            <div style={{ flex: 1, textAlign: "center" }}>
              <div style={{ fontSize: "2.5rem", fontWeight: "bold", color: "var(--primary)" }}>
                {hospital.communityData?.averageCostRwf > 0 
                  ? `${hospital.communityData.averageCostRwf.toLocaleString()} RWF` 
                  : "N/A"
                }
              </div>
              <div style={{ fontSize: "0.8rem", color: "var(--text-secondary)" }}>
                Median price ({hospital.communityData?.costSubmissionCount || 0} submissions)
              </div>
            </div>
          </div>

          <h3 style={{ fontSize: "1rem", marginBottom: "0.5rem", color: "var(--text-primary)" }}>
            Median Cost by Insurance Network
          </h3>
          <div className="table-container" style={{ maxHeight: "250px", overflowY: "auto" }}>
            <table>
              <thead>
                <tr>
                  <th>Insurance</th>
                  <th>Network Status</th>
                  <th>Median Base Cost</th>
                </tr>
              </thead>
              <tbody>
                {insuranceOptions.map((ins) => {
                  const isInNetwork = hospital.acceptedInsurance.includes(ins);
                  const cost = hospital.communityData?.averageCostByInsurance?.[ins];
                  return (
                    <tr key={ins}>
                      <td style={{ fontWeight: "600", textTransform: "uppercase" }}>{ins}</td>
                      <td>
                        <span className={`badge ${isInNetwork ? "badge-success" : "badge-danger"}`}>
                          {isInNetwork ? "In Network" : "Out of Network"}
                        </span>
                      </td>
                      <td style={{ color: cost ? "var(--primary)" : "var(--text-secondary)", fontWeight: "600" }}>
                        {cost ? `${cost.toLocaleString()} RWF` : "No data submitted"}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div className="card" style={{ marginTop: "1.5rem" }}>
        <h2 className="card-title">📖 Approved Historical Reviews</h2>
        {reviews.length === 0 ? (
          <p style={{ color: "var(--text-secondary)", padding: "1rem" }}>
            No reviews have been submitted yet. When students submit visit costs and ratings, they will appear here once approved.
          </p>
        ) : (
          <div className="table-container">
            <table>
              <thead>
                <tr>
                  <th>Approved Date</th>
                  <th>Rating</th>
                  <th>Consultation Cost</th>
                  <th>Co-pay Paid</th>
                  <th>Visit Details</th>
                  <th>Approved By</th>
                </tr>
              </thead>
              <tbody>
                {reviews.map((rev) => (
                  <tr key={rev.id}>
                    <td>{new Date(rev.approvedAt).toLocaleDateString()}</td>
                    <td>{renderStars(rev.rating)}</td>
                    <td style={{ fontWeight: 600, color: "var(--primary)" }}>
                      {rev.costPaidRwf ? `${rev.costPaidRwf.toLocaleString()} RWF` : "-"}
                    </td>
                    <td>
                      {rev.copayPaidRwf ? `${rev.copayPaidRwf.toLocaleString()} RWF` : "-"}
                      {rev.insuranceUsed && (
                        <div style={{ fontSize: "0.75rem", color: "var(--text-secondary)" }}>
                          ({rev.insuranceUsed.toUpperCase()})
                        </div>
                      )}
                    </td>
                    <td>
                      {rev.visitReason && <div><strong>Reason:</strong> {rev.visitReason}</div>}
                      {rev.notes && <div style={{ fontSize: "0.85rem", color: "var(--text-secondary)", fontStyle: "italic" }}>"{rev.notes}"</div>}
                    </td>
                    <td style={{ fontSize: "0.85rem", color: "var(--text-secondary)" }}>{rev.approvedBy}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
