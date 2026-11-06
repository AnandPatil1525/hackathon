# PS-14: Community Problem Reporting and Resolution Platform (CivicPulse)

[![Next.js](https://img.shields.io/badge/Next.js-14.2-black?logo=next.js)](https://nextjs.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.5-blue?logo=typescript)](https://www.typescriptlang.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql)](https://www.postgresql.org/)
[![PostGIS](https://img.shields.io/badge/PostGIS-3.4-green?logo=postgis)](https://postgis.net/)
[![Prisma](https://img.shields.io/badge/Prisma-5.19-2D3748?logo=prisma)](https://www.prisma.io/)
[![Tailwind CSS](https://img.shields.io/badge/TailwindCSS-3.4-38B2AC?logo=tailwind-css)](https://tailwindcss.com/)

An enterprise-ready, full-stack civic infrastructure platform designed to bridge citizens and municipal authorities. Citizens can report infrastructure issues (broken streetlights, potholes, garbage overflows, water leaks) with photographic evidence and geospatial coordinates, while municipal administrators can prioritize, track status changes, audit lifecycle transitions, and eliminate duplicate reports via **PostGIS geospatial indexing**.

---

## 🏛️ Architecture Overview

The platform uses a unified full-stack architecture leveraging Next.js App Router for both server-rendered UI and RESTful API routes, backed by Prisma ORM and PostgreSQL with PostGIS extensions:

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Layer                             │
│   • Next.js App Router (React Server & Client Components)   │
│   • Tailwind CSS Design System + Lucide Icons               │
│   • Dynamic Incident Feed & Citizen/Admin Persona Switcher  │
└──────────────────────────────┬──────────────────────────────┘
                               │ HTTP / JSON
┌──────────────────────────────▼──────────────────────────────┐
│                    Server / API Layer                       │
│   • Next.js Route Handlers (/api/reports, /api/users)       │
│   • Zod Schema Validation & Sanitization                    │
│   • Business Service Layer (ReportService, UserService)     │
└──────────────────────────────┬──────────────────────────────┘
                               │ Prisma ORM / PostGIS Raw SQL
┌──────────────────────────────▼──────────────────────────────┐
│                   Database Layer                            │
│   • PostgreSQL 16 with PostGIS 3.4 Spatial Extension        │
│   • Models: User, Report, StatusLog                         │
│   • Spatial Indexing: ST_DWithin & ST_DistanceSphere        │
└─────────────────────────────────────────────────────────────┘
```

---

## 📂 Project Structure

```
├── docker-compose.yml           # PostgreSQL 16 + PostGIS 3.4 container ready out of the box
├── package.json                 # Core dependencies and npm lifecycle scripts
├── tsconfig.json                # TypeScript strict configuration
├── tailwind.config.ts           # Tailwind CSS configuration
├── postcss.config.mjs           # PostCSS configuration
├── next.config.mjs              # Next.js optimization configuration
├── .env.example                 # Environment variable templates
├── .env                         # Local environment configuration
├── prisma/
│   ├── schema.prisma            # Prisma schema (User, Report, StatusLog, Enums)
│   ├── seed.ts                  # Comprehensive seeding script with dummy Citizens & Admins
│   └── init-postgis.sql         # PostGIS extension initialization SQL
└── src/
    ├── app/
    │   ├── api/
    │   │   ├── reports/
    │   │   │   ├── route.ts          # GET (list/filter) & POST (create report)
    │   │   │   ├── [id]/
    │   │   │   │   ├── route.ts      # GET single report details & audit history
    │   │   │   │   └── status/
    │   │   │   │       └── route.ts  # POST status transition with audit log & proof image
    │   │   │   └── nearby/
    │   │   │       └── route.ts      # GET PostGIS radius proximity query for duplicate detection
    │   │   ├── users/
    │   │   │   └── route.ts          # GET & POST users
    │   │   ├── health/
    │   │   │   └── route.ts          # Health check endpoint & PostGIS verification
    │   │   ├── globals.css           # Global Tailwind directives
    │   │   ├── layout.tsx            # Root HTML layout & font metadata
    │   │   └── page.tsx              # Interactive Civic Incident Feed & Dashboard
    ├── components/
    │   ├── Navbar.tsx                # App navigation & Citizen/Admin persona toggle
    │   ├── StatsOverview.tsx         # Incident KPI cards (Total, In Progress, Resolved, Critical)
    │   ├── ReportCard.tsx            # Rich incident card with audit trail accordion
    │   └── QuickReportModal.tsx      # Modal form with HTML5 GPS auto-detection
    ├── lib/
    │   ├── prisma.ts                 # PrismaClient singleton instance
    │   ├── postgis.ts                # Spatial proximity helper (ST_DWithin & Haversine fallback)
    │   └── utils.ts                  # Styling utilities (clsx, twMerge, formatters)
    ├── server/
    │   ├── services/
    │   │   ├── report.service.ts     # Transactional report service layer
    │   │   └── user.service.ts       # User service layer
    │   └── validations/
    │       └── report.schema.ts      # Zod validation schemas
    └── types/
        └── index.ts                  # TypeScript domain interfaces and enum types
```

---

## 🗄️ Data Schemas & Relationships

### 1. `User` Model
Represents both Citizens submitting reports and Municipal Admins managing resolution workflows.
- `id`: UUID (Primary Key)
- `name`: String
- `email`: String (Unique)
- `role`: Enum (`CITIZEN`, `ADMIN`), default: `CITIZEN`
- `createdAt`: DateTime
- `updatedAt`: DateTime
- **Relations:** Has many `Report`s, has many `StatusLog`s (as `changedByUser`).

### 2. `Report` Model
Core entity representing a community infrastructure problem.
- `id`: UUID (Primary Key)
- `userId`: UUID (Foreign Key to `User`)
- `title`: String
- `description`: Text
- `category`: Enum (`STREETLIGHT`, `ROAD_POTHOLE`, `GARBAGE`, `WATER_SANITATION`, `OTHER`)
- `latitude`: Float? (WGS 84 decimal degrees)
- `longitude`: Float? (WGS 84 decimal degrees)
- `imageUrl`: String? (Photo evidence URL)
- `status`: Enum (`UNVERIFIED`, `IN_REVIEW`, `IN_PROGRESS`, `RESOLVED`, `REJECTED`), default: `UNVERIFIED`
- `priority`: Enum (`LOW`, `MEDIUM`, `HIGH`, `CRITICAL`), default: `MEDIUM`
- `isDuplicate`: Boolean, default: `false`
- `duplicateOfId`: UUID? (Self-referencing Foreign Key to primary `Report`)
- `createdAt`: DateTime
- `updatedAt`: DateTime
- **Relations:** Belongs to `User`, has many `StatusLog`s, self-relation for duplicates (`duplicateOf` / `duplicates`).

### 3. `StatusLog` Model
Immutable audit log tracking every status transition, the admin responsible, internal resolution notes, and optional proof image.
- `id`: UUID (Primary Key)
- `reportId`: UUID (Foreign Key to `Report`)
- `changedByUserId`: UUID (Foreign Key to `User`)
- `oldStatus`: Enum `ReportStatus`?
- `newStatus`: Enum `ReportStatus`
- `notes`: Text?
- `proofImageUrl`: String? (Proof of repair / work order completion)
- `createdAt`: DateTime

---

## ⚡ Quickstart Guide

### 1. Clone & Install Dependencies
```bash
# Clone the repository
git clone <repo-url>
cd ps14-community-platform

# Install npm dependencies
npm install
```

### 2. Configure Environment Variables
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```
Ensure your database connection string in `.env` matches your PostgreSQL instance:
```env
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/community_reports?schema=public"
```

### 3. Start Database (Docker Compose with PostGIS)
A ready-to-run PostGIS docker container is included:
```bash
# Spin up PostgreSQL 16 with PostGIS 3.4
npm run docker:up
```

### 4. Push Schema & Seed Initial Data
```bash
# Push Prisma schema to PostgreSQL
npm run db:push

# Run seed script with dummy Citizens, Admins, Reports, and Status Logs
npm run db:seed
```

### 5. Start the Development Server
```bash
npm run dev
```
Open [http://localhost:3000](http://localhost:3000) in your browser to access the dashboard.

---

## 👥 Seed Data Overview

The seed script (`prisma/seed.ts`) populates the database with realistic civic data:

| User Name | Role | Email | Purpose |
| :--- | :--- | :--- | :--- |
| **Sarah Chen** | `ADMIN` | `admin.chen@cityworks.gov` | Lead Municipal Admin (approves & resolves work orders) |
| **David O'Connor** | `ADMIN` | `admin.david@cityworks.gov` | Field Operations Supervisor (reviews duplicates) |
| **Alex Rivera** | `CITIZEN` | `alex.rivera@civic.local` | Citizen reporting streetlight issues |
| **Priya Sharma** | `CITIZEN` | `priya.sharma@civic.local` | Citizen reporting critical potholes & water main leaks |
| **Marcus Vance** | `CITIZEN` | `marcus.vance@civic.local` | Citizen reporting commercial dumpster overflow |

### Seeded Incidents:
1. **Broken Streetlight Pole #42 on Elm & 5th Ave** (`STREETLIGHT`, `HIGH`, `IN_PROGRESS`) — Includes two status transition logs.
2. **Severe Pothole on Broadway Boulevard** (`ROAD_POTHOLE`, `CRITICAL`, `IN_REVIEW`) — High-priority road hazard.
3. **Bad road crater Broadway & 4th** (`ROAD_POTHOLE`, `MEDIUM`, `REJECTED`) — Flagged as duplicate of incident #2 (`isDuplicate: true`).
4. **Burst Water Pipe Flooding Pedestrian Crosswalk** (`WATER_SANITATION`, `CRITICAL`, `RESOLVED`) — Fully resolved incident with repair proof image.
5. **Overflowing Commercial Dumpster & Illegal Dumping** (`GARBAGE`, `MEDIUM`, `UNVERIFIED`) — Fresh citizen submission.

---

## 🛡️ Phase 3: Admin Review, Duplicate Engine & Strict Resolution Rules

Phase 3 introduces enterprise operational rigor for municipal administrators:

### 1. Role-Based Access Control (RBAC)
- **Protected Endpoints:** All status mutations, priority changes, and duplicate merges require `ADMIN` role verification.
- **Client & Server Enforcement:** Non-admin requests receive `403 Forbidden: Only users with the ADMIN role can modify report status or priority.`
- **UI Lockdown:** The Admin Console view automatically locks out non-admins and presents an elevation request banner.

### 2. Duplicate Detection Engine (100m Proximity Radar)
- **Automated Spatial & Semantic Scan:** When an administrator opens a case, the platform automatically scans a **100-meter radius** using PostGIS `ST_DWithin` and compares category and text keywords.
- **Candidate Scoring:** Displays match confidence (e.g. `95% Match`), proximity in meters (e.g. `14.2m away`), and matching tokens.
- **1-Click Duplicate Linker:** Admins can click **"Mark as Duplicate & Link"** to automatically:
  1. Flag the report as `isDuplicate: true`
  2. Set `duplicateOfId` to the primary report ID
  3. Transition status to `REJECTED`
  4. Record an audit log entry in `StatusLog`

### 3. Strict Resolution Guardrails
- **Zero-Tolerance Resolution Gate:** Prohibits closing any case as `RESOLVED` unless the administrator provides **both**:
  1. **Mandatory Text Notes** detailing the engineering fix (minimum 5 characters).
  2. **Proof of Resolution Photo** (uploaded through the Privacy Shield EXIF scrubber).
- **Dual Enforcement:** Throws strict client-side form validation errors and server-side `400 Bad Request` schema rejections (`RESOLUTION_GUARDRAIL_VIOLATION`) if either field is missing.

---

## 🗺️ Phase 4: Public Interactive Map & Hotspot Analytics

Phase 4 integrates a full-district geospatial visualization layer with automated problem clustering:

### 1. Interactive Geospatial Map (`InteractiveMap`)
- **Map Backdrop:** OpenStreetMap vector coordinate grid with terrain markers for civic districts, waterfronts, and municipal parks.
- **Marker Color-Coding Standard:**
  - 🔴 **Red Marker:** `UNVERIFIED` / `HIGH` or `CRITICAL` priority incidents.
  - 🟡 **Yellow Marker:** `IN_PROGRESS` active maintenance tickets.
  - 🟢 **Green Marker:** `RESOLVED` verified completed repairs.
  - ⚪ **Gray Marker:** `DUPLICATE` (or `REJECTED`) linked reports.

### 2. Hotspot Clustering & Recurring Problem Density
- **Automated Density Algorithm:** Groups incidents located within a 150m radius occurring over configurable time windows (Past 7, 30, or 90 days).
- **Pulsing Heat Aura Discs:** Visually flags recurring problem hotspots with animated warning halos and report count tags.
- **Hotspot Filter:** 1-Click toggle to filter and view only verified hazard clusters.
- **Incident Pin Details Popup:** Click any pin to inspect the title, category badge, status tag, image preview, coordinates, and jump to the full case record.

---

## 🧪 Phase 5: Automated Testing & Browser Verification

Phase 5 introduces an automated test suite verifying all 5 core platform constraints:

```bash
# Execute the automated constraint verification suite
npm run test:constraints
```

### Verified Test Scenarios (5/5 Passing):
1. **Optional Location & Default `UNVERIFIED` State:** Submitting a report without coordinates succeeds with `status: "UNVERIFIED"` and `latitude/longitude: null`.
2. **Privacy Shield EXIF Scrubber:** Submits geotagged JPEG containing `0xFFE1` APP1 GPS/device markers; verifies that all metadata segments are purged while image decodability is preserved.
3. **Strict Resolution Guardrail:** Proves that attempting to set status to `RESOLVED` without fix notes or proof photo throws validation rejections (`RESOLUTION_GUARDRAIL_VIOLATION`), while providing both allows resolution.
4. **100m/10m Duplicate Detection Engine:** Submits two incidents 6.5m apart; verifies duplicate engine flags candidate with 100% confidence score and matching keyword tokens.
5. **RBAC Security Guard:** Confirms that non-admin requests attempting status transitions are rejected with `403 Forbidden` (`RBAC_FORBIDDEN`).

---

## 📡 API Reference

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/health` | System health check & PostGIS extension status |
| `GET` | `/api/reports` | List reports with category, status, priority, and pagination filters |
| `POST` | `/api/reports` | Create new community report (validated via Zod) |
| `GET` | `/api/reports/:id` | Fetch detailed report with full audit history |
| `POST` | `/api/reports/:id/status` | Update status (RBAC protected, strict resolution guardrail enforced) |
| `GET` | `/api/reports/:id/duplicates` | Run 100m Duplicate Detection Engine (PostGIS + semantic keywords) |
| `POST` | `/api/reports/:id/duplicate` | 1-Click duplicate merger (links to primary report & sets REJECTED) |
| `GET` | `/api/analytics/hotspots` | Density cluster query (identifies recurring problem hotspots) |
| `GET` | `/api/reports/nearby` | Spatial query using PostGIS `ST_DWithin` & `ST_DistanceSphere` |
| `GET` | `/api/users` | List users filtered by role (`CITIZEN` or `ADMIN`) |
| `POST` | `/api/users` | Register a new user |

---

## 🗺️ PostGIS Duplicate Detection Strategy

Duplicate reports often occur when multiple citizens report the same pothole or broken streetlight from slightly different coordinates. To address this, the platform provides a dedicated PostGIS spatial query:

```sql
SELECT 
  id, title, category, latitude, longitude,
  ROUND(
    ST_DistanceSphere(
      ST_SetSRID(ST_MakePoint(longitude, latitude), 4326),
      ST_SetSRID(ST_MakePoint($targetLng, $targetLat), 4326)
    )::numeric, 1
  )::float as "distanceMeters"
FROM "Report"
WHERE ST_DWithin(
  ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
  ST_SetSRID(ST_MakePoint($targetLng, $targetLat), 4326)::geography,
  50 -- Proximity threshold in meters
);
```
When a citizen attempts to report an issue within a 50m radius of an existing unresolved incident in the same category, the system flags the report as a potential duplicate and can automatically link it via `duplicateOfId`.

---

## 🛡️ Phase 2: Citizen Reporting & Privacy Shield

Phase 2 introduces strict citizen privacy protection, interactive spatial selection, and a lifecycle tracking dashboard:

### 1. Privacy Shield Pre-Processor Service (`PrivacyShieldService`)
- **EXIF Scrubbing:** Intercepts uploaded JPEG/PNG binary streams, parsing and stripping `APP1` (`0xFFE1` EXIF/XMP/IPTC) segments and PNG `eXIf`/`tEXt`/`zTXt`/`iTXt` metadata chunks before file persistence.
- **Privacy Assurance:** Purges camera model, serial numbers, date-time stamps, and embedded GPS coordinates to safeguard citizen privacy while preserving visual clarity.
- **Upload Endpoint:** `POST /api/upload` handles multipart form data or base64 streams, returns the sanitized file URL, and provides a real-time sanitization report.

### 2. Interactive Spatial Pinning (`LocationPicker`)
- Citizens can provide optional incident coordinates using:
  - **Device Location:** Browser HTML5 Geolocation API (`navigator.geolocation`).
  - **Interactive Map Click:** Click/tap anywhere on the vector street grid canvas to drop an incident pin.
  - **Coordinate Presets & Manual Clear:** Fine-tune coordinates or clear them entirely.

### 3. Default State Policy & Visual Tags
- **Strict Constraint:** Every newly submitted problem report automatically initializes with `status: "UNVERIFIED"`.
- **Public UI Tag:** Renders the mandatory banner: **`Unverified Report - Pending Admin Review`** across the public incident feed and card views.

### 4. Citizen Status Tracking Dashboard (`CitizenDashboard`)
- **4-Stage Resolution Stepper:** Real-time visual progress indicator (`1. Submission` ➔ `2. Triage & Review` ➔ `3. Field Dispatch` ➔ `4. Resolution`).
- **Timestamped Audit Trail:** Chronological log of every status transition with municipal admin notes.
- **Official Resolution Proof:** Inspect post-repair proof photographs submitted by field engineers alongside the original citizen evidence.

---

## 🚀 Next Phases (Roadmap)
- **Phase 2:** AI Computer Vision Pipeline for automated classification and fake/spam image detection.
- **Phase 3:** Automated Department Routing & Dispatch (integration with municipal work order ticketing).
- **Phase 4:** Real-time Citizen Push Notifications & Interactive Map with Heatmap Clusters.
- **Phase 5:** PWA / Offline-First Mobile Client with background GPS geotagging.

