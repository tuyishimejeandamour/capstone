import { auth, db } from "./firebase";
import { 
  onAuthStateChanged, 
  signInWithEmailAndPassword, 
  signOut 
} from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";

export interface AdminUser {
  uid: string;
  email: string;
  displayName?: string;
  role: string;
}

export function subscribeAuth(callback: (user: AdminUser | null, loading: boolean) => void) {
  callback(null, true);
  return onAuthStateChanged(auth, async (firebaseUser) => {
    if (firebaseUser) {
      try {
        // Verify user against admin_users collection
        const docSnap = await getDoc(doc(db, "admin_users", firebaseUser.uid));
        if (docSnap.exists()) {
          const data = docSnap.data();
          callback({
            uid: firebaseUser.uid,
            email: firebaseUser.email || "",
            displayName: data.displayName || firebaseUser.displayName || "",
            role: data.role || "admin"
          }, false);
        } else {
          // If not registered as admin, sign out automatically
          await signOut(auth);
          callback(null, false);
        }
      } catch (e) {
        await signOut(auth);
        callback(null, false);
      }
    } else {
      callback(null, false);
    }
  });
}
