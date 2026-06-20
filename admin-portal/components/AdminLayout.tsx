"use client";

import { useEffect, useState } from "react";
import { useRouter, usePathname } from "next/navigation";
import { subscribeAuth, AdminUser } from "../lib/auth";
import { auth } from "../lib/firebase";
import { signOut } from "firebase/auth";
import Link from "next/link";

interface AdminLayoutProps {
  children: React.ReactNode;
}

export default function AdminLayout({ children }: AdminLayoutProps) {
  const [user, setUser] = useState<AdminUser | null>(null);
  const [loading, setLoading] = useState(true);
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    const unsubscribe = subscribeAuth((currentUser, isLoading) => {
      setUser(currentUser);
      setLoading(isLoading);

      if (!isLoading && !currentUser && pathname !== "/login") {
        router.push("/login");
      }
    });

    return () => unsubscribe();
  }, [router, pathname]);

  const handleLogout = async () => {
    try {
      await signOut(auth);
      router.push("/login");
    } catch (e) {
      console.error("Logout error:", e);
    }
  };

  if (loading) {
    return (
      <div className="login-wrapper">
        <div style={{ textAlign: "center" }}>
          <div className="login-title" style={{ marginBottom: "1rem" }}>Ranga Admin</div>
          <div style={{ color: "var(--text-secondary)" }}>Loading secure session...</div>
        </div>
      </div>
    );
  }

  // If on login page, just render children directly (no sidebar layout)
  if (pathname === "/login") {
    return <>{children}</>;
  }

  if (!user) {
    return null; // Will redirect in useEffect
  }

  return (
    <div className="admin-container">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <span>🏥</span> Ranga Admin
        </div>
        <nav className="sidebar-nav">
          <Link href="/dashboard" className={`nav-item ${pathname === "/dashboard" ? "active" : ""}`}>
            <span>📊</span> Dashboard
          </Link>
          <Link href="/submissions" className={`nav-item ${pathname === "/submissions" ? "active" : ""}`}>
            <span>📥</span> Submissions
          </Link>
          <Link href="/hospitals" className={`nav-item ${pathname.startsWith("/hospitals") ? "active" : ""}`}>
            <span>🏥</span> Hospitals
          </Link>
        </nav>
        <div className="sidebar-footer">
          <div style={{ fontSize: "0.85rem", color: "var(--text-secondary)", marginBottom: "0.5rem", padding: "0 1rem" }}>
            Logged in as:<br/>
            <strong style={{ color: "var(--text-primary)", wordBreak: "break-all" }}>{user.email}</strong>
          </div>
          <button onClick={handleLogout} className="btn-logout">
            <span>🚪</span> Logout
          </button>
        </div>
      </aside>

      <main className="main-content">
        {children}
      </main>
    </div>
  );
}
