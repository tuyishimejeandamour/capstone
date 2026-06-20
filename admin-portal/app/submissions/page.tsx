"use client";

import { useEffect, useState } from "react";
import { auth } from "../../lib/firebase";
import { 
  Submission, 
  subscribePendingSubmissions, 
  approveSubmission, 
  rejectSubmission, 
  toggleFlagSubmission 
} from "../../lib/firestore";

export default function SubmissionsPage() {
  const [submissions, setSubmissions] = useState<Submission[]>([]);
  const [loading, setLoading] = useState(true);
  const [actioningId, setActioningId] = useState<string | null>(null);

  useEffect(() => {
    const unsubscribe = subscribePendingSubmissions((items) => {
      setSubmissions(items);
      setLoading(false);
    });
    return () => unsubscribe();
  }, []);

  const handleApprove = async (sub: Submission) => {
    if (confirm(`Approve this submission for ${sub.hospitalName}?`)) {
      setActioningId(sub.id);
      try {
        const adminEmail = auth.currentUser?.email || "admin@ranga.rw";
        await approveSubmission(sub, adminEmail);
      } catch (e) {
        console.error("Error approving submission:", e);
        alert("Failed to approve submission.");
      } finally {
        setActioningId(null);
      }
    }
  };

  const handleReject = async (subId: string) => {
    if (confirm("Are you sure you want to reject this submission? It will be archived and won't affect hospital stats.")) {
      setActioningId(subId);
      try {
        await rejectSubmission(subId);
      } catch (e) {
        console.error("Error rejecting submission:", e);
        alert("Failed to reject submission.");
      } finally {
        setActioningId(null);
      }
    }
  };

  const handleToggleFlag = async (sub: Submission) => {
    setActioningId(sub.id);
    try {
      await toggleFlagSubmission(sub.id, !sub.flagged);
    } catch (e) {
      console.error("Error flagging submission:", e);
      alert("Failed to update flag state.");
    } finally {
      setActioningId(null);
    }
  };

  const renderStars = (rating?: number) => {
    if (!rating) return "-";
    return (
      <span className="rating-stars">
        {"★".repeat(rating)}
        {"☆".repeat(5 - rating)}
      </span>
    );
  };

  const formatCost = (val?: number) => {
    if (val === undefined || val === null) return "-";
    return `${val.toLocaleString()} RWF`;
  };

  const formatTimeAgo = (dateStr: string) => {
    try {
      const date = new Date(dateStr);
      const diffMs = Date.now() - date.getTime();
      const diffMins = Math.floor(diffMs / 60000);
      if (diffMins < 1) return "Just now";
      if (diffMins < 60) return `${diffMins}m ago`;
      const diffHours = Math.floor(diffMins / 60);
      if (diffHours < 24) return `${diffHours}h ago`;
      return date.toLocaleDateString();
    } catch (_) {
      return dateStr;
    }
  };

  if (loading) {
    return <div style={{ padding: "2rem", color: "var(--text-secondary)" }}>Loading moderation queue...</div>;
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Moderation Queue</h1>
          <p className="page-subtitle">Verify student-submitted ratings and costs</p>
        </div>
        <div className="badge badge-info">{submissions.length} Pending</div>
      </div>

      <div className="card" style={{ padding: 0 }}>
        {submissions.length === 0 ? (
          <div style={{ padding: "3rem", textAlign: "center", color: "var(--text-secondary)" }}>
            <h3>🎉 Moderation queue is empty!</h3>
            <p style={{ marginTop: "0.5rem" }}>All student submissions have been processed.</p>
          </div>
        ) : (
          <div className="table-container">
            <table>
              <thead>
                <tr>
                  <th>Hospital</th>
                  <th>Verification Code</th>
                  <th>Type</th>
                  <th>Rating</th>
                  <th>Cost Paid</th>
                  <th>Co-pay Paid</th>
                  <th>Details</th>
                  <th>Submitted</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {submissions.map((sub) => (
                  <tr key={sub.id} className={sub.flagged ? "flagged" : ""}>
                    <td style={{ fontWeight: 600 }}>{sub.hospitalName}</td>
                    <td>
                      <code style={{ fontSize: "0.95rem", color: "var(--info)", fontWeight: "bold" }}>
                        {sub.studentVerificationCode}
                      </code>
                    </td>
                    <td>
                      <span className={`badge ${
                        sub.type === "rating_and_cost" ? "badge-info" : 
                        sub.type === "cost_only" ? "badge-success" : "badge-warning"
                      }`}>
                        {sub.type.replace("_", " ")}
                      </span>
                    </td>
                    <td>{renderStars(sub.rating)}</td>
                    <td style={{ color: "var(--primary)", fontWeight: "600" }}>{formatCost(sub.costPaidRwf)}</td>
                    <td style={{ color: "var(--text-primary)" }}>
                      {formatCost(sub.copayPaidRwf)} 
                      {sub.insuranceUsed && (
                        <div style={{ fontSize: "0.75rem", color: "var(--text-secondary)" }}>
                          via {sub.insuranceUsed.toUpperCase()}
                        </div>
                      )}
                    </td>
                    <td>
                      <div style={{ maxWidth: "200px" }}>
                        {sub.visitReason && <div><strong>Reason:</strong> {sub.visitReason}</div>}
                        {sub.notes && <div style={{ fontSize: "0.8rem", color: "var(--text-secondary)", marginTop: "0.1rem" }}>"{sub.notes}"</div>}
                      </div>
                    </td>
                    <td>{formatTimeAgo(sub.submittedAt)}</td>
                    <td className="actions-cell">
                      <button 
                        onClick={() => handleApprove(sub)} 
                        disabled={actioningId === sub.id} 
                        className="btn btn-primary" 
                        style={{ padding: "0.4rem 0.8rem", fontSize: "0.8rem" }}
                      >
                        Approve
                      </button>
                      <button 
                        onClick={() => handleToggleFlag(sub)} 
                        disabled={actioningId === sub.id} 
                        className="btn btn-warning" 
                        style={{ padding: "0.4rem 0.8rem", fontSize: "0.8rem" }}
                      >
                        {sub.flagged ? "Unflag" : "Flag"}
                      </button>
                      <button 
                        onClick={() => handleReject(sub.id)} 
                        disabled={actioningId === sub.id} 
                        className="btn btn-danger" 
                        style={{ padding: "0.4rem 0.8rem", fontSize: "0.8rem" }}
                      >
                        Reject
                      </button>
                    </td>
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
