# B CloudBeaver connection check

Observed on 16 September 2026 through the existing local CloudBeaver interface at http://localhost:8978/.

- Updated existing A2 connection label to **A2 GlucoLink v0.1 - PostgreSQL**.
- Target changed from glucolink to **glucolink_a2**, host postgres, port 5432.
- Used existing local course authentication for the test; no passwords included here.
- CloudBeaver displayed **Connection is established**, PostgreSQL JDBC Driver 42.7.11, server PostgreSQL 15.18.
- The displayed connection-test time was **2026-09-16T07:48:46Z**.
- Saved configuration was observed with the new label and target database; save button returned to disabled state.
- Save credentials for all users with access remained unchecked.
- After reconnecting with the existing local course account, the browser tree visibly showed glucolink_a2 > Schemas > audit, cleansed, curated, public, raw, reporting, src_gp, src_lab and src_pharm. The browser was left on this expanded tree for the user.

This is local browser-connection evidence only. No teammate access or independent reproduction is claimed.
