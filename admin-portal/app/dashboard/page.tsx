"use client";

import { useEffect, useState } from "react";
import { db } from "../../lib/firebase";
import { collection, getDocs, query, where, onSnapshot } from "firebase/firestore";
import Link from "next/link";
import { Hospital, Submission } from "../../lib/firestore";

export default function DashboardPage() {
  const [hospitalCount, setHospitalCount] = useState(0);
  const [pendingCount, setPendingCount] = useState(0);
  const [totalSubmissionsCount, setTotalSubmissionsCount] = useState(0);
  const [overallRating, setOverallRating] = useState(0);
  const [recentPending, setRecentPending] = useState<Submission[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // 1. Get hospitals statistics
    const fetchHospitals = async () => {
      try {
        const snap = await getDocs(collection(db, "hospitals"));
        setHospitalCount(snap.size);

        let ratingSum = 0;
        let ratingCount = 0;
        let totalSubs = 0;

        snap.forEach((doc) => {
          const data = doc.data() as Hospital;
          if (data.communityData) {
            ratingSum += (data.communityData.averageRating || 0) * (data.communityData.ratingCount || 0);
            ratingCount += data.communityData.ratingCount || 0;
            totalSubs += (data.communityData.ratingCount || 0) + (data.communityData.costSubmissionCount || 0);
          }
        });

        setOverallRating(ratingCount > 0 ? ratingSum / ratingCount : 0);
        setTotalSubmissionsCount(totalSubs);
      } catch (e) {
        console.error("Error fetching hospitals:", e);
      }
    };

    fetchHospitals();

    // 2. Real-time pending submissions listener
    const q = query(collection(db, "pending_submissions"), where("status", "==", "pending"));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      setPendingCount(snapshot.size);
      const items: Submission[] = [];
      snapshot.forEach((doc) => {
        items.push({ id: doc.id, ...doc.data() } as Submission);
      });
      setRecentPending(items.slice(0, 5)); // Show latest 5
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  if (loading) {
    return <div style={{ padding: "2rem", color: "var(--text-secondary)" }}>Loading dashboard analytics...</div>;
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Analytics Dashboard</h1>
          <p className="page-subtitle">Ranga Hospital Platform Overview</p>
        </div>
      </div>

      <div className="grid-cols-4">
        <div className="card stat-card">
          <span className="stat-label">🕐 Pending Reviews</span>
          <span className="stat-value" style={{ color: "var(--warning)" }}>{pendingCount}</span>
          <span className="stat-indicator" style={{ color: "var(--text-secondary)" }}>Needs approval</span>
        </div>

        <div className="card stat-card">
          <span className="stat-label">🏥 Total Hospitals</span>
          <span className="stat-value">{hospitalCount}</span>
          <span className="stat-indicator" style={{ color: "var(--primary)" }}>Active in Rwanda</span>
        </div>

        <div className="card stat-card">
          <span className="stat-label">⭐ Average Rating</span>
          <span className="stat-value" style={{ color: "var(--warning)" }}>{overallRating.toFixed(1)}</span>
          <span className="stat-indicator" style={{ color: "var(--text-secondary)" }}>Across all hospitals</span>
        </div>

        <div className="card stat-card">
          <span className="stat-label">📈 Total Submissions</span>
          <span className="stat-value">{totalSubmissionsCount}</span>
          <span className="stat-indicator" style={{ color: "var(--info)" }}>Approved reviews/costs</span>
        </div>
      </div>

      <div className="grid-cols-2" style={{ marginTop: "1rem" }}>
        <div className="card">
          <h2 className="card-title">🕐 Recent Pending Submissions</h2>
          {recentPending.length === 0 ? (
            <p style={{ color: "var(--text-secondary)" }}>No pending submissions to review. Excellent work!</p>
          ) : (
            <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              {recentPending.map((sub) => (
                <div key={sub.id} style={{ display: "flex", justifyContent: "space-between", padding: "0.75rem", background: "rgba(255,255,255,0.03)", borderRadius: "0.5rem" }}>
                  <div>
                    <strong>{sub.hospitalName}</strong>
                    <div style={{ fontSize: "0.85rem", color: "var(--text-secondary)", marginTop: "0.25rem" }}>
                      Verification code: <code>{sub.studentVerificationCode}</code>
                    </div>
                  </div>
                  <div style={{ textAlign: "right" }}>
                    {sub.rating && <span style={{ color: "var(--warning)", marginRight: "0.5rem" }}>⭐ {sub.rating}</span>}
                    {sub.costPaidRwf && <div style={{ fontSize: "0.85rem", color: "var(--primary)", marginTop: "0.25rem" }}>{sub.costPaidRwf.toLocaleString()} RWF</div>}
                  </div>
                </div>
              ))}
              <div style={{ marginTop: "0.5rem" }}>
                <Link href="/submissions" className="btn btn-secondary" style={{ width: "100%" }}>
                  Go to Moderation Queue
                </Link>
              </div>
            </div>
          )}
        </div>

        <div className="card">
          <h2 className="card-title">⚡ Quick Management Actions</h2>
          <div style={{ display: "grid", gap: "1rem" }}>
            <Link href="/hospitals" className="btn btn-outline" style={{ justifyContent: "flex-start", padding: "1rem" }}>
              <span>🏥</span> Manage Hospital Listings & Insurance Networks
            </Link>
            <Link href="/submissions" className="btn btn-outline" style={{ justifyContent: "flex-start", padding: "1rem" }}>
              <span>📥</span> Moderation & Verify Student Visit Codes
            </Link>
            <div style={{ padding: "1rem", background: "rgba(16, 185, 129, 0.05)", borderRadius: "0.5rem", border: "1px dashed rgba(16, 185, 129, 0.2)", fontSize: "0.85rem", color: "var(--text-secondary)", lineHeight: "1.4" }}>
              💡 <strong>Verification Policy:</strong> Verify that student verification codes match the RNG-XXXX format and costs match public/private hospital baselines. Flag any submissions with extreme outliers.
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
