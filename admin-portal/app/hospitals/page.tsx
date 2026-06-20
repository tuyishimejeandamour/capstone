"use client";

import { useEffect, useState } from "react";
import { Hospital, getHospitals, saveHospital } from "../../lib/firestore";
import Link from "next/link";

export default function HospitalsPage() {
  const [hospitals, setHospitals] = useState<Hospital[]>([]);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingHospital, setEditingHospital] = useState<Hospital | null>(null);

  // Form states
  const [formId, setFormId] = useState("");
  const [formName, setFormName] = useState("");
  const [formAddress, setFormAddress] = useState("");
  const [formDistrict, setFormDistrict] = useState("");
  const [formProvince, setFormProvince] = useState("");
  const [formLat, setFormLat] = useState(-1.935);
  const [formLng, setFormLng] = useState(30.08);
  const [formPhone, setFormPhone] = useState("");
  const [formType, setFormType] = useState("public");
  const [formOpeningHours, setFormOpeningHours] = useState("24/7");
  const [formEmergencyUnit, setFormEmergencyUnit] = useState(true);
  const [formInsurance, setFormInsurance] = useState<string[]>([]);
  const [formSpecialties, setFormSpecialties] = useState<string[]>([]);
  const [customSpecialty, setCustomSpecialty] = useState("");
  const [saving, setSaving] = useState(false);

  const insuranceOptions = ["mutuelle", "rssb", "mmi", "sanlam", "britam", "uap", "radiant"];
  const specialtyOptions = ["general medicine", "cardiology", "ophthalmology", "surgery", "orthopedics", "counseling", "psychiatry", "mental health", "dentistry", "pediatrics", "obstetrics", "gynecology", "dermatology", "emergency"];

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    setLoading(true);
    try {
      const data = await getHospitals();
      setHospitals(data);
    } catch (e) {
      console.error("Error fetching hospitals:", e);
    } finally {
      setLoading(false);
    }
  };

  const handleSeed = async () => {
    if (confirm("Are you sure you want to seed the database with 20 Rwandan hospitals? This will populate initial locations, coordinates, and specialty networks.")) {
      setSaving(true);
      try {
        const seedData = [
          {
            id: "king_faisal_hospital",
            name: "King Faisal Hospital",
            address: "KG 544 St, Kacyiru, Kigali",
            district: "Gasabo",
            province: "Kigali",
            lat: -1.9355,
            lng: 30.0928,
            phone: "+250 252 582 421",
            type: "private",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["rssb", "sanlam", "britam", "uap", "radiant"],
            specialties: ["general medicine", "cardiology", "ophthalmology", "surgery", "pediatrics", "obstetrics", "gynecology", "dermatology", "emergency"],
            communityData: { averageRating: 4.4, ratingCount: 12, averageCostRwf: 15000, costSubmissionCount: 6, averageCostByInsurance: { "rssb": 2250, "sanlam": 2250 } }
          },
          {
            id: "chuk_kigali",
            name: "CHUK (University Teaching Hospital of Kigali)",
            address: "KN 4 Ave, Nyarugenge, Kigali",
            district: "Nyarugenge",
            province: "Kigali",
            lat: -1.9441,
            lng: 30.0619,
            phone: "+250 788 300 001",
            type: "public",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["mutuelle", "rssb", "mmi", "sanlam", "britam", "uap", "radiant"],
            specialties: ["general medicine", "cardiology", "ophthalmology", "surgery", "pediatrics", "obstetrics", "gynecology", "psychiatry", "orthopedics", "emergency"],
            communityData: { averageRating: 4.1, ratingCount: 18, averageCostRwf: 3000, costSubmissionCount: 11, averageCostByInsurance: { "mutuelle": 300, "rssb": 450 } }
          },
          {
            id: "rwanda_military_hospital",
            name: "Rwanda Military Hospital",
            address: "Kanombe Road, Kanombe, Kigali",
            district: "Kicukiro",
            province: "Kigali",
            lat: -1.9568,
            lng: 30.1554,
            phone: "+250 252 586 420",
            type: "public",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["mmi", "rssb", "sanlam", "radiant"],
            specialties: ["general medicine", "cardiology", "surgery", "orthopedics", "dentistry", "emergency"],
            communityData: { averageRating: 4.2, ratingCount: 8, averageCostRwf: 4000, costSubmissionCount: 4, averageCostByInsurance: { "mmi": 400, "rssb": 600 } }
          },
          {
            id: "kibagabaga_hospital",
            name: "Kibagabaga District Hospital",
            address: "Kibagabaga Road, Gasabo, Kigali",
            district: "Gasabo",
            province: "Kigali",
            lat: -1.9322,
            lng: 30.1167,
            phone: "+250 788 301 234",
            type: "public",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["mutuelle", "rssb", "radiant"],
            specialties: ["general medicine", "surgery", "pediatrics", "obstetrics", "gynecology", "counseling", "emergency"],
            communityData: { averageRating: 3.8, ratingCount: 14, averageCostRwf: 2500, costSubmissionCount: 8, averageCostByInsurance: { "mutuelle": 250, "rssb": 375 } }
          },
          {
            id: "muhima_hospital",
            name: "Muhima Hospital",
            address: "KN 1 Rd, Muhima, Kigali",
            district: "Nyarugenge",
            province: "Kigali",
            lat: -1.9413,
            lng: 30.0574,
            phone: "+250 252 575 115",
            type: "public",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["mutuelle", "rssb", "radiant"],
            specialties: ["general medicine", "pediatrics", "obstetrics", "gynecology", "emergency"],
            communityData: { averageRating: 3.9, ratingCount: 10, averageCostRwf: 2000, costSubmissionCount: 6, averageCostByInsurance: { "mutuelle": 200, "rssb": 300 } }
          },
          {
            id: "masaka_hospital",
            name: "Masaka District Hospital",
            address: "Masaka, Kicukiro, Kigali",
            district: "Kicukiro",
            province: "Kigali",
            lat: -1.9892,
            lng: 30.2078,
            phone: "+250 788 565 789",
            type: "public",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["mutuelle", "rssb", "radiant"],
            specialties: ["general medicine", "pediatrics", "obstetrics", "surgery", "emergency"],
            communityData: { averageRating: 3.7, ratingCount: 6, averageCostRwf: 2000, costSubmissionCount: 3, averageCostByInsurance: { "mutuelle": 200, "rssb": 300 } }
          },
          {
            id: "legacy_clinics",
            name: "Legacy Clinics",
            address: "KK 507 St, Kimihurura, Kigali",
            district: "Gasabo",
            province: "Kigali",
            lat: -1.9497,
            lng: 30.0955,
            phone: "+250 788 381 222",
            type: "private",
            openingHours: "Monday-Saturday 7:00 AM - 10:00 PM",
            emergencyUnit: false,
            acceptedInsurance: ["rssb", "sanlam", "britam", "uap", "radiant"],
            specialties: ["general medicine", "cardiology", "ophthalmology", "gynecology", "dentistry", "dermatology", "counseling"],
            communityData: { averageRating: 4.5, ratingCount: 11, averageCostRwf: 12000, costSubmissionCount: 5, averageCostByInsurance: { "rssb": 1800, "sanlam": 1800 } }
          },
          {
            id: "polyclinique_du_plateau",
            name: "Polyclinique du Plateau",
            address: "KN 3 Rd, Nyarugenge, Kigali",
            district: "Nyarugenge",
            province: "Kigali",
            lat: -1.9458,
            lng: 30.0612,
            phone: "+250 252 578 333",
            type: "private",
            openingHours: "8:00 AM - 6:00 PM",
            emergencyUnit: false,
            acceptedInsurance: ["rssb", "sanlam", "britam", "uap", "radiant"],
            specialties: ["general medicine", "ophthalmology", "dentistry", "gynecology"],
            communityData: { averageRating: 4.1, ratingCount: 7, averageCostRwf: 10000, costSubmissionCount: 3, averageCostByInsurance: { "rssb": 1500, "sanlam": 1500 } }
          },
          {
            id: "kacyiru_hospital",
            name: "Kacyiru Hospital",
            address: "KG 7 Ave, Kacyiru, Kigali",
            district: "Gasabo",
            province: "Kigali",
            lat: -1.9333,
            lng: 30.0888,
            phone: "+250 252 583 318",
            type: "public",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["mutuelle", "rssb", "radiant"],
            specialties: ["general medicine", "pediatrics", "counseling", "mental health", "emergency"],
            communityData: { averageRating: 4.0, ratingCount: 9, averageCostRwf: 2200, costSubmissionCount: 5, averageCostByInsurance: { "mutuelle": 220, "rssb": 330 } }
          },
          {
            id: "la_croix_du_sud",
            name: "La Croix du Sud Hospital",
            address: "KG 201 St, Remera, Kigali",
            district: "Gasabo",
            province: "Kigali",
            lat: -1.9575,
            lng: 30.1215,
            phone: "+250 252 580 541",
            type: "private",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["rssb", "sanlam", "britam", "uap", "radiant"],
            specialties: ["general medicine", "pediatrics", "obstetrics", "gynecology", "surgery", "emergency"],
            communityData: { averageRating: 4.3, ratingCount: 16, averageCostRwf: 14000, costSubmissionCount: 7, averageCostByInsurance: { "rssb": 2100, "sanlam": 2100 } }
          },
          {
            id: "caraes_ndera",
            name: "Caraes Ndera Hospital (Mental Health)",
            address: "Ndera, Gasabo, Kigali",
            district: "Gasabo",
            province: "Kigali",
            lat: -1.9421,
            lng: 30.1704,
            phone: "+250 252 515 504",
            type: "public",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["mutuelle", "rssb", "mmi", "radiant"],
            specialties: ["psychiatry", "counseling", "mental health", "general medicine"],
            communityData: { averageRating: 4.5, ratingCount: 22, averageCostRwf: 3500, costSubmissionCount: 14, averageCostByInsurance: { "mutuelle": 350, "rssb": 525 } }
          },
          {
            id: "gisenyi_hospital",
            name: "Gisenyi District Hospital",
            address: "Gisenyi, Rubavu",
            district: "Rubavu",
            province: "Western Province",
            lat: -1.7011,
            lng: 29.2618,
            phone: "+250 252 540 123",
            type: "public",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["mutuelle", "rssb", "radiant"],
            specialties: ["general medicine", "surgery", "pediatrics", "obstetrics", "emergency"],
            communityData: { averageRating: 3.9, ratingCount: 5, averageCostRwf: 2000, costSubmissionCount: 2, averageCostByInsurance: { "mutuelle": 200, "rssb": 300 } }
          },
          {
            id: "ruhengeri_hospital",
            name: "Ruhengeri Referral Hospital",
            address: "Musanze, Northern Province",
            district: "Musanze",
            province: "Northern Province",
            lat: -1.5033,
            lng: 29.6344,
            phone: "+250 252 546 003",
            type: "public",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["mutuelle", "rssb", "mmi", "radiant"],
            specialties: ["general medicine", "surgery", "pediatrics", "obstetrics", "gynecology", "orthopedics", "emergency"],
            communityData: { averageRating: 4.0, ratingCount: 11, averageCostRwf: 2400, costSubmissionCount: 5, averageCostByInsurance: { "mutuelle": 240, "rssb": 360 } }
          },
          {
            id: "chub_huye",
            name: "CHUB (University Teaching Hospital of Butare)",
            address: "Huye, Southern Province",
            district: "Huye",
            province: "Southern Province",
            lat: -2.6019,
            lng: 29.7431,
            phone: "+250 252 530 089",
            type: "public",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["mutuelle", "rssb", "mmi", "sanlam", "radiant"],
            specialties: ["general medicine", "cardiology", "surgery", "pediatrics", "obstetrics", "gynecology", "psychiatry", "emergency"],
            communityData: { averageRating: 4.1, ratingCount: 13, averageCostRwf: 2800, costSubmissionCount: 7, averageCostByInsurance: { "mutuelle": 280, "rssb": 420 } }
          },
          {
            id: "kibuye_hospital",
            name: "Kibuye Hospital",
            address: "Karongi, Western Province",
            district: "Karongi",
            province: "Western Province",
            lat: -2.0622,
            lng: 29.3514,
            phone: "+250 788 411 222",
            type: "public",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["mutuelle", "rssb", "radiant"],
            specialties: ["general medicine", "surgery", "pediatrics", "obstetrics", "emergency"],
            communityData: { averageRating: 3.6, ratingCount: 4, averageCostRwf: 2000, costSubmissionCount: 2, averageCostByInsurance: { "mutuelle": 200, "rssb": 300 } }
          },
          {
            id: "kabgayi_hospital",
            name: "Kabgayi Hospital",
            address: "Muhanga, Southern Province",
            district: "Muhanga",
            province: "Southern Province",
            lat: -2.0792,
            lng: 29.7578,
            phone: "+250 252 562 101",
            type: "public",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["mutuelle", "rssb", "radiant"],
            specialties: ["general medicine", "ophthalmology", "surgery", "pediatrics", "obstetrics", "emergency"],
            communityData: { averageRating: 4.2, ratingCount: 14, averageCostRwf: 2300, costSubmissionCount: 6, averageCostByInsurance: { "mutuelle": 230, "rssb": 345 } }
          },
          {
            id: "rwamagana_hospital",
            name: "Rwamagana Provincial Hospital",
            address: "Rwamagana, Eastern Province",
            district: "Rwamagana",
            province: "Eastern Province",
            lat: -1.9511,
            lng: 30.4328,
            phone: "+250 252 567 114",
            type: "public",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["mutuelle", "rssb", "radiant"],
            specialties: ["general medicine", "surgery", "pediatrics", "obstetrics", "gynecology", "emergency"],
            communityData: { averageRating: 3.9, ratingCount: 9, averageCostRwf: 2200, costSubmissionCount: 4, averageCostByInsurance: { "mutuelle": 220, "rssb": 330 } }
          },
          {
            id: "gahini_hospital",
            name: "Gahini Hospital",
            address: "Kayonza, Eastern Province",
            district: "Kayonza",
            province: "Eastern Province",
            lat: -1.8219,
            lng: 30.4683,
            phone: "+250 788 302 444",
            type: "public",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["mutuelle", "rssb", "radiant"],
            specialties: ["general medicine", "orthopedics", "ophthalmology", "surgery", "counseling"],
            communityData: { averageRating: 4.3, ratingCount: 10, averageCostRwf: 2500, costSubmissionCount: 5, averageCostByInsurance: { "mutuelle": 250, "rssb": 375 } }
          },
          {
            id: "kinihira_hospital",
            name: "Kinihira Provincial Hospital",
            address: "Rulindo, Northern Province",
            district: "Rulindo",
            province: "Northern Province",
            lat: -1.6492,
            lng: 29.9881,
            phone: "+250 788 322 555",
            type: "public",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["mutuelle", "rssb", "radiant"],
            specialties: ["general medicine", "surgery", "pediatrics", "obstetrics", "emergency"],
            communityData: { averageRating: 3.8, ratingCount: 6, averageCostRwf: 2100, costSubmissionCount: 3, averageCostByInsurance: { "mutuelle": 210, "rssb": 315 } }
          },
          {
            id: "nyamata_hospital",
            name: "Nyamata District Hospital",
            address: "Bugesera, Eastern Province",
            district: "Bugesera",
            province: "Eastern Province",
            lat: -2.1481,
            lng: 30.1383,
            phone: "+250 252 565 050",
            type: "public",
            openingHours: "24/7",
            emergencyUnit: true,
            acceptedInsurance: ["mutuelle", "rssb", "radiant"],
            specialties: ["general medicine", "pediatrics", "obstetrics", "counseling", "emergency"],
            communityData: { averageRating: 3.9, ratingCount: 8, averageCostRwf: 2100, costSubmissionCount: 4, averageCostByInsurance: { "mutuelle": 210, "rssb": 315 } }
          }
        ];

        for (const h of seedData) {
          await saveHospital(h);
        }
        alert("Database seeded successfully with 20 Rwandan hospitals!");
        fetchData();
      } catch (e) {
        console.error("Failed to seed database:", e);
        alert("Failed to seed database.");
      } finally {
        setSaving(false);
      }
    }
  };

  const handleEdit = (h: Hospital) => {
    setEditingHospital(h);
    setFormId(h.id);
    setFormName(h.name);
    setFormAddress(h.address);
    setFormDistrict(h.district);
    setFormProvince(h.province);
    setFormLat(h.lat);
    setFormLng(h.lng);
    setFormPhone(h.phone || "");
    setFormType(h.type || "public");
    setFormOpeningHours(h.openingHours || "24/7");
    setFormEmergencyUnit(h.emergencyUnit);
    setFormInsurance(h.acceptedInsurance || []);
    setFormSpecialties(h.specialties || []);
    setShowForm(true);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const handleAddNew = () => {
    setEditingHospital(null);
    setFormId("");
    setFormName("");
    setFormAddress("");
    setFormDistrict("");
    setFormProvince("");
    setFormLat(-1.9441);
    setFormLng(30.0619);
    setFormPhone("");
    setFormType("public");
    setFormOpeningHours("24/7");
    setFormEmergencyUnit(true);
    setFormInsurance(["mutuelle", "rssb"]);
    setFormSpecialties(["general medicine"]);
    setShowForm(true);
  };

  const handleInsuranceToggle = (ins: string) => {
    if (formInsurance.includes(ins)) {
      setFormInsurance(formInsurance.filter((x) => x !== ins));
    } else {
      setFormInsurance([...formInsurance, ins]);
    }
  };

  const handleSpecialtyToggle = (spec: string) => {
    if (formSpecialties.includes(spec)) {
      setFormSpecialties(formSpecialties.filter((x) => x !== spec));
    } else {
      setFormSpecialties([...formSpecialties, spec]);
    }
  };

  const handleAddCustomSpecialty = () => {
    const clean = customSpecialty.trim().toLowerCase();
    if (clean && !formSpecialties.includes(clean)) {
      setFormSpecialties([...formSpecialties, clean]);
      setCustomSpecialty("");
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);

    const targetId = formId.trim() || formName.toLowerCase().replace(/[^a-z0-9]+/g, "_");

    try {
      await saveHospital({
        id: targetId,
        name: formName,
        address: formAddress,
        district: formDistrict,
        province: formProvince,
        lat: Number(formLat),
        lng: Number(formLng),
        phone: formPhone || undefined,
        type: formType,
        openingHours: formOpeningHours || undefined,
        emergencyUnit: formEmergencyUnit,
        acceptedInsurance: formInsurance,
        specialties: formSpecialties,
        communityData: editingHospital?.communityData || {
          averageRating: 0,
          ratingCount: 0,
          averageCostRwf: 0,
          costSubmissionCount: 0,
          averageCostByInsurance: {}
        }
      });
      setShowForm(false);
      setEditingHospital(null);
      fetchData();
    } catch (e) {
      console.error("Error saving hospital:", e);
      alert("Failed to save hospital.");
    } finally {
      setSaving(false);
    }
  };

  const filteredHospitals = hospitals.filter((h) => 
    h.name.toLowerCase().includes(search.toLowerCase()) ||
    h.district.toLowerCase().includes(search.toLowerCase()) ||
    h.specialties.some(s => s.toLowerCase().includes(search.toLowerCase()))
  );

  if (loading && hospitals.length === 0) {
    return <div style={{ padding: "2rem", color: "var(--text-secondary)" }}>Loading hospitals list...</div>;
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Hospital Listings</h1>
          <p className="page-subtitle">Manage registered hospitals, locations, and specialties</p>
        </div>
        {!showForm && (
          <div style={{ display: "flex", gap: "1rem" }}>
            <button onClick={handleSeed} className="btn btn-secondary" disabled={saving}>
              🌱 Seed Initial Data
            </button>
            <button onClick={handleAddNew} className="btn btn-primary">
              ➕ Add Hospital
            </button>
          </div>
        )}
      </div>

      {showForm && (
        <div className="card" style={{ marginBottom: "2rem" }}>
          <h2 className="card-title">{editingHospital ? `✏️ Edit ${formName}` : "➕ Add New Hospital"}</h2>
          <form onSubmit={handleSubmit}>
            <div className="grid-cols-2">
              <div className="form-group">
                <label className="form-label">Hospital Document ID (e.g. king_faisal_hospital)</label>
                <input
                  className="form-input"
                  type="text"
                  placeholder="Leave blank to generate from name"
                  value={formId}
                  onChange={(e) => setFormId(e.target.value)}
                  disabled={!!editingHospital}
                />
              </div>
              <div className="form-group">
                <label className="form-label">Hospital Name</label>
                <input
                  className="form-input"
                  type="text"
                  required
                  placeholder="e.g. King Faisal Hospital"
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                />
              </div>
            </div>

            <div className="grid-cols-2">
              <div className="form-group">
                <label className="form-label">Physical Address</label>
                <input
                  className="form-input"
                  type="text"
                  required
                  placeholder="e.g. KG 544 St, Kacyiru, Kigali"
                  value={formAddress}
                  onChange={(e) => setFormAddress(e.target.value)}
                />
              </div>
              <div className="form-group">
                <div style={{ display: "flex", gap: "1rem" }}>
                  <div style={{ flex: 1 }}>
                    <label className="form-label">District</label>
                    <input
                      className="form-input"
                      type="text"
                      required
                      placeholder="e.g. Gasabo"
                      value={formDistrict}
                      onChange={(e) => setFormDistrict(e.target.value)}
                    />
                  </div>
                  <div style={{ flex: 1 }}>
                    <label className="form-label">Province</label>
                    <input
                      className="form-input"
                      type="text"
                      required
                      placeholder="e.g. Kigali"
                      value={formProvince}
                      onChange={(e) => setFormProvince(e.target.value)}
                    />
                  </div>
                </div>
              </div>
            </div>

            <div className="grid-cols-4">
              <div className="form-group">
                <label className="form-label">Latitude</label>
                <input
                  className="form-input"
                  type="number"
                  step="0.000001"
                  required
                  value={formLat}
                  onChange={(e) => setFormLat(Number(e.target.value))}
                />
              </div>
              <div className="form-group">
                <label className="form-label">Longitude</label>
                <input
                  className="form-input"
                  type="number"
                  step="0.000001"
                  required
                  value={formLng}
                  onChange={(e) => setFormLng(Number(e.target.value))}
                />
              </div>
              <div className="form-group">
                <label className="form-label">Phone</label>
                <input
                  className="form-input"
                  type="text"
                  placeholder="e.g. +250 252 582 421"
                  value={formPhone}
                  onChange={(e) => setFormPhone(e.target.value)}
                />
              </div>
              <div className="form-group">
                <label className="form-label">Facility Type</label>
                <select className="form-select" value={formType} onChange={(e) => setFormType(e.target.value)}>
                  <option value="public">Public Hospital / Health Center</option>
                  <option value="private">Private Hospital / Clinic</option>
                  <option value="referral">National Referral Hospital</option>
                </select>
              </div>
            </div>

            <div className="grid-cols-2">
              <div className="form-group">
                <label className="form-label">Opening Hours</label>
                <input
                  className="form-input"
                  type="text"
                  value={formOpeningHours}
                  onChange={(e) => setFormOpeningHours(e.target.value)}
                />
              </div>
              <div className="form-group" style={{ justifyContent: "center" }}>
                <label className="checkbox-label" style={{ marginTop: "1.5rem" }}>
                  <input
                    type="checkbox"
                    className="checkbox-input"
                    checked={formEmergencyUnit}
                    onChange={(e) => setFormEmergencyUnit(e.target.checked)}
                  />
                  Has Emergency ER Unit
                </label>
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Accepted Insurance Networks</label>
              <div className="checkbox-list">
                {insuranceOptions.map((ins) => (
                  <label key={ins} className="checkbox-label">
                    <input
                      type="checkbox"
                      className="checkbox-input"
                      checked={formInsurance.includes(ins)}
                      onChange={() => handleInsuranceToggle(ins)}
                    />
                    {ins.toUpperCase()}
                  </label>
                ))}
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Specialties Available</label>
              <div className="checkbox-list" style={{ marginBottom: "1rem" }}>
                {specialtyOptions.map((spec) => (
                  <label key={spec} className="checkbox-label">
                    <input
                      type="checkbox"
                      className="checkbox-input"
                      checked={formSpecialties.includes(spec)}
                      onChange={() => handleSpecialtyToggle(spec)}
                    />
                    {spec}
                  </label>
                ))}
              </div>
              <div style={{ display: "flex", gap: "0.5rem", maxWidth: "400px" }}>
                <input
                  className="form-input"
                  type="text"
                  placeholder="Other specialty..."
                  value={customSpecialty}
                  onChange={(e) => setCustomSpecialty(e.target.value)}
                />
                <button type="button" onClick={handleAddCustomSpecialty} className="btn btn-secondary">
                  Add
                </button>
              </div>
              <div style={{ fontSize: "0.85rem", color: "var(--text-secondary)", marginTop: "0.5rem" }}>
                Selected specialties: <em>{formSpecialties.join(", ") || "none"}</em>
              </div>
            </div>

            <div style={{ display: "flex", gap: "1rem", marginTop: "2rem" }}>
              <button className="btn btn-primary" type="submit" disabled={saving}>
                {saving ? "Saving..." : "Save Hospital"}
              </button>
              <button className="btn btn-secondary" type="button" onClick={() => setShowForm(false)}>
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      <div className="card">
        <div style={{ marginBottom: "1rem", display: "flex", gap: "1rem" }}>
          <input
            className="form-input"
            type="text"
            placeholder="Search hospitals by name, location, or specialty..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>Hospital</th>
                <th>Location</th>
                <th>Type</th>
                <th>ER Unit</th>
                <th>Insurance Networks</th>
                <th>Specialties</th>
                <th>Stats</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredHospitals.map((h) => (
                <tr key={h.id}>
                  <td>
                    <Link href={`/hospitals/${h.id}`} style={{ fontWeight: "600", fontSize: "0.95rem" }}>
                      {h.name}
                    </Link>
                  </td>
                  <td>{h.address} ({h.district})</td>
                  <td>
                    <span className={`badge ${h.type === "private" ? "badge-info" : "badge-success"}`}>
                      {h.type}
                    </span>
                  </td>
                  <td>{h.emergencyUnit ? "✅ Yes" : "❌ No"}</td>
                  <td>
                    <div style={{ display: "flex", gap: "0.25rem", flexWrap: "wrap" }}>
                      {h.acceptedInsurance.map((ins) => (
                        <span key={ins} className="badge badge-success" style={{ fontSize: "0.7rem", padding: "0.1rem 0.3rem" }}>
                          {ins}
                        </span>
                      ))}
                    </div>
                  </td>
                  <td style={{ maxWidth: "200px" }}>
                    <div style={{ textOverflow: "ellipsis", overflow: "hidden", whiteSpace: "nowrap", fontSize: "0.85rem", color: "var(--text-secondary)" }} title={h.specialties.join(", ")}>
                      {h.specialties.join(", ")}
                    </div>
                  </td>
                  <td>
                    <div style={{ fontSize: "0.85rem" }}>
                      ⭐ {h.communityData?.averageRating?.toFixed(1) || "0.0"} ({h.communityData?.ratingCount || 0} reviews)<br/>
                      💵 {h.communityData?.costSubmissionCount || 0} prices
                    </div>
                  </td>
                  <td className="actions-cell">
                    <button onClick={() => handleEdit(h)} className="btn btn-outline" style={{ padding: "0.4rem 0.8rem", fontSize: "0.8rem" }}>
                      Edit
                    </button>
                    <Link href={`/hospitals/${h.id}`} className="btn btn-secondary" style={{ padding: "0.4rem 0.8rem", fontSize: "0.8rem" }}>
                      Metrics
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
