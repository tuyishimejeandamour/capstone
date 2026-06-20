import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

// Helper to calculate median cost
function calculateMedian(values: number[]): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const half = Math.floor(sorted.length / 2);
  if (sorted.length % 2 !== 0) {
    return sorted[half];
  }
  return Math.round((sorted[half - 1] + sorted[half]) / 2);
}

export const onSubmissionApproved = functions.firestore
  .document("approved_submissions/{submissionId}")
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    if (!data) return;

    const hospitalId = data.hospitalId;
    if (!hospitalId) {
      functions.logger.error("No hospitalId found in approved submission.");
      return;
    }

    try {
      // 1. Fetch all approved submissions for this hospital
      const querySnapshot = await db
        .collection("approved_submissions")
        .where("hospitalId", "==", hospitalId)
        .get();

      const ratings: number[] = [];
      const costs: number[] = [];
      const costsByInsurance: Record<string, number[]> = {};

      querySnapshot.forEach((doc) => {
        const sub = doc.data();

        // Collect ratings
        if (sub.rating !== undefined && sub.rating !== null) {
          ratings.push(Number(sub.rating));
        }

        // Collect costs
        if (sub.costPaidRwf !== undefined && sub.costPaidRwf !== null) {
          const cost = Number(sub.costPaidRwf);
          costs.push(cost);

          // Group by insurance
          if (sub.insuranceUsed) {
            const insKey = String(sub.insuranceUsed).toLowerCase().trim();
            if (!costsByInsurance[insKey]) {
              costsByInsurance[insKey] = [];
            }
            costsByInsurance[insKey].push(cost);
          }
        }
      });

      // 2. Recompute statistics
      const averageRating = ratings.length > 0 
        ? Math.round((ratings.reduce((a, b) => a + b, 0) / ratings.length) * 10) / 10 
        : 0;
      
      const ratingCount = ratings.length;
      
      const averageCostRwf = calculateMedian(costs);
      const costSubmissionCount = costs.length;

      const averageCostByInsurance: Record<string, number> = {};
      for (const insKey of Object.keys(costsByInsurance)) {
        averageCostByInsurance[insKey] = calculateMedian(costsByInsurance[insKey]);
      }

      // 3. Update the hospital document
      const hospitalRef = db.collection("hospitals").doc(hospitalId);
      await hospitalRef.set({
        communityData: {
          averageRating,
          ratingCount,
          averageCostRwf,
          costSubmissionCount,
          averageCostByInsurance,
          lastAggregatedAt: new Date().toISOString()
        },
        lastUpdated: new Date().toISOString()
      }, { merge: true });

      functions.logger.info(`Successfully recomputed communityData for hospital ${hospitalId}:`, {
        averageRating,
        ratingCount,
        averageCostRwf,
        costSubmissionCount,
        averageCostByInsurance
      });

    } catch (error) {
      functions.logger.error("Error in onSubmissionApproved trigger:", error);
    }
  });
